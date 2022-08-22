require_relative "../../../spec/spec_helper"
require "base64"
require "flores/random"
require 'concurrent/atomic/count_down_latch'
require "logstash/outputs/elasticsearch"

require 'logstash/plugin_mixins/ecs_compatibility_support/spec_helper'

describe LogStash::Outputs::ElasticSearch do
  subject(:elasticsearch_output_instance) { described_class.new(options) }
  let(:options) { {} }
  let(:maximum_seen_major_version) { [6,7,8].sample }

  let(:do_register) { true }

  let(:stub_http_client_pool!) do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:start)
  end

  let(:after_successful_connection_thread_mock) do
    double('after_successful_connection_thread', value: true)
  end

  before(:each) do
    if do_register
      stub_http_client_pool!

      allow(subject).to receive(:finish_register) # stub-out thread completion (to avoid error log entries)

      # emulate 'successful' ES connection on the same thread
      allow(subject).to receive(:after_successful_connection) { |&block| block.call }.
          and_return after_successful_connection_thread_mock
      allow(subject).to receive(:stop_after_successful_connection_thread)

      subject.register

      allow(subject.client).to receive(:maximum_seen_major_version).at_least(:once).and_return(maximum_seen_major_version)
      allow(subject.client).to receive(:get_xpack_info)

      subject.client.pool.adapter.manticore.respond_with(:body => "{}")
    end
  end

  after(:each) do
    subject.close
  end


  context "with an active instance" do
    let(:options) {
      {
        "index" => "my-index",
        "hosts" => ["localhost","localhost:9202"],
        "path" => "some-path",
        "manage_template" => false
      }
    }

    let(:manticore_urls) { subject.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    let(:stub_http_client_pool!) do
      [:start_resurrectionist, :start_sniffer, :healthcheck!].each do |method|
        allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(method)
      end
    end

    describe "getting a document type" do
      context "if document_type isn't set" do
        let(:options) { super().merge("document_type" => nil)}
        context "for 7.x elasticsearch clusters" do
          let(:maximum_seen_major_version) { 7 }
          it "should return '_doc'" do
            expect(subject.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("_doc")
          end
        end

        context "for 6.x elasticsearch clusters" do
          let(:maximum_seen_major_version) { 6 }
          it "should return 'doc'" do
            expect(subject.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("doc")
          end
        end
      end

      context "with 'document type set'" do
        let(:options) { super().merge("document_type" => "bar")}
        it "should get the event type from the 'document_type' setting" do
          expect(subject.send(:get_event_type, LogStash::Event.new())).to eql("bar")
        end
      end
    end

    describe "building an event action tuple" do
      context "for 7.x elasticsearch clusters" do
        let(:maximum_seen_major_version) { 7 }
        it "should not include '_type' when 'document_type' is not explicitly defined" do
          action_tuple = subject.send(:event_action_tuple, LogStash::Event.new("type" => "foo"))
          action_params = action_tuple[1]
          expect(action_params).not_to include(:_type => "_doc")
        end

        context "with 'document type set'" do
          let(:options) { super().merge("document_type" => "bar")}
          it "should get the event type from the 'document_type' setting" do
            action_tuple = subject.send(:event_action_tuple, LogStash::Event.new("type" => "foo"))
            action_params = action_tuple[1]
            expect(action_params).to include(:_type => "bar")
          end
        end
      end

      context "for 8.x elasticsearch clusters" do
        let(:maximum_seen_major_version) { 8 }
        it "should not include '_type'" do
          action_tuple = subject.send(:event_action_tuple, LogStash::Event.new("type" => "foo"))
          action_params = action_tuple[1]
          expect(action_params).not_to include(:_type)
        end

        context "with 'document type set'" do
          let(:options) { super().merge("document_type" => "bar")}
          it "should not include '_type'" do
            action_tuple = subject.send(:event_action_tuple, LogStash::Event.new("type" => "foo"))
            action_params = action_tuple[1]
            expect(action_params).not_to include(:_type)
          end
        end
      end
    end

    describe "with auth" do
      let(:user) { "myuser" }
      let(:password) { ::LogStash::Util::Password.new("mypassword") }

      shared_examples "an authenticated config" do
        it "should set the URL auth correctly" do
          expect(manticore_url.user).to eq user
        end
      end

      context "as part of a URL" do
        let(:options) {
          super().merge("hosts" => ["http://#{user}:#{password.value}@localhost:9200"])
        }

        include_examples("an authenticated config")
      end

      context "as a hash option" do
          let(:options) {
            super().merge!(
              "user" => user,
              "password" => password
            )
        }

        include_examples("an authenticated config")
      end

      context 'cloud_auth also set' do
        let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
        let(:options) { { "user" => user, "password" => password, "cloud_auth" => "elastic:my-passwd-00" } }

        it "should fail" do
          expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
        end
      end

      context 'api_key also set' do
        let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
        let(:options) { { "user" => user, "password" => password, "api_key" => "some_key" } }

        it "should fail" do
          expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
        end
      end

    end

    describe "with path" do
      it "should properly create a URI with the path" do
        expect(subject.path).to eql(options["path"])
      end

        it "should properly set the path on the HTTP client adding slashes" do
        expect(manticore_url.path).to eql("/" + options["path"] + "/")
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:options) { super().merge("path" => "/some-path/") }

        it "should properly set the path on the HTTP client without adding slashes" do
          expect(manticore_url.path).to eql(options["path"])
        end
      end

      context "with a URI based path" do
        let(:options) do
          o = super()
          o.delete("path")
          o["hosts"] = ["http://localhost:9200/mypath/"]
          o
        end
        let(:client_host_path) { manticore_url.path }

        it "should initialize without error" do
          expect { subject }.not_to raise_error
        end

        it "should use the URI path" do
          expect(client_host_path).to eql("/mypath/")
        end

        context "with a path option but no URL path" do
          let(:options) do
            o = super()
            o["path"] = "/override/"
            o["hosts"] = ["http://localhost:9200"]
            o
          end

          it "should initialize without error" do
            expect { subject }.not_to raise_error
          end

          it "should use the option path" do
            expect(client_host_path).to eql("/override/")
          end
        end

        # If you specify the path in two spots that is an error!
        context "with a path option and a URL path" do
          let(:do_register) { false } # Register will fail
          let(:options) do
            o = super()
            o["path"] = "/override"
            o["hosts"] = ["http://localhost:9200/mypath/"]
            o
          end

          it "should initialize with an error" do
            expect { subject.register }.to raise_error(LogStash::ConfigurationError)
          end
        end
      end
    end

    describe "without a port specified" do
      let(:options) { super().merge('hosts' => 'localhost') }
      it "should properly set the default port (9200) on the HTTP client" do
        expect(manticore_url.port).to eql(9200)
      end
    end
    describe "with a port other than 9200 specified" do
      let(:options) { super().merge('hosts' => 'localhost:9202') }
      it "should properly set the specified port on the HTTP client" do
        expect(manticore_url.port).to eql(9202)
      end
    end

    describe "when 'dlq_custom_codes'" do
      let(:options) { super().merge('dlq_custom_codes' => [404]) }
      let(:do_register) { false }

      context "contains already defined codes" do
        it "should raise a configuration error" do
          expect{ subject.register }.to raise_error(LogStash::ConfigurationError, /are already defined as standard DLQ error codes/)
        end
      end
    end if LOGSTASH_VERSION > '7.0'

    describe "#multi_receive" do
      let(:events) { [double("one"), double("two"), double("three")] }
      let(:events_tuples) { [double("one t"), double("two t"), double("three t")] }

      before do
        allow(subject).to receive(:retrying_submit).with(anything)
        events.each_with_index do |e,i|
          allow(subject).to receive(:event_action_tuple).with(e).and_return(events_tuples[i])
        end
        subject.multi_receive(events)
      end

    end

    context "429 errors" do
      let(:event) { ::LogStash::Event.new("foo" => "bar") }
      let(:error) do
        ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(
          429, double("url").as_null_object, request_body, double("response body")
        )
      end
      let(:logger) { double("logger").as_null_object }
      let(:response) { { :errors => [], :items => [] } }

      let(:request_body) { double(:request_body, :bytesize => 1023) }

      before(:each) do

        i = 0
        bulk_param =  [["index", anything, event.to_hash]]

        allow(subject).to receive(:logger).and_return(logger)

        # Fail the first time bulk is called, succeed the next time
        allow(subject.client).to receive(:bulk).with(bulk_param) do
          i += 1
          if i == 1
            raise error
          end
        end.and_return(response)
        subject.multi_receive([event])
      end

      it "should retry the 429 till it goes away" do
        expect(subject.client).to have_received(:bulk).twice
      end

      it "should log a debug message" do
        expect(subject.logger).to have_received(:debug).with(/Encountered a retryable error/i, anything)
      end
    end

    context "unexpected bulk response" do
      let(:options) do
        { "hosts" => "127.0.0.1:9999", "index" => "%{foo}", "manage_template" => false }
      end

      let(:events) { [ ::LogStash::Event.new("foo" => "bar1"), ::LogStash::Event.new("foo" => "bar2") ] }

      let(:bulk_response) do
        # shouldn't really happen but we've seen this happen - here ES returns more items than were sent
        { "took"=>1, "ingest_took"=>9, "errors"=>true,
          "items"=>[{"index"=>{"_index"=>"bar1", "_type"=>"_doc", "_id"=>nil, "status"=>500,
                              "error"=>{"type" => "illegal_state_exception",
                                      "reason" => "pipeline with id [test-ingest] could not be loaded, caused by [ElasticsearchParseException[Error updating pipeline with id [test-ingest]]; nested: ElasticsearchException[java.lang.IllegalArgumentException: no enrich index exists for policy with name [test-metadata1]]; nested: IllegalArgumentException[no enrich index exists for policy with name [test-metadata1]];; ElasticsearchException[java.lang.IllegalArgumentException: no enrich index exists for policy with name [test-metadata1]]; nested: IllegalArgumentException[no enrich index exists for policy with name [test-metadata1]];; java.lang.IllegalArgumentException: no enrich index exists for policy with name [test-metadata1]]"
                                      }
                              }
                    },
                    # NOTE: this is an artificial success (usually everything fails with a 500) but even if some doc where
                    # to succeed due the unexpected reponse items we can not clearly identify which actions to retry ...
                    {"index"=>{"_index"=>"bar2", "_type"=>"_doc", "_id"=>nil, "status"=>201}},
                    {"index"=>{"_index"=>"bar2", "_type"=>"_doc", "_id"=>nil, "status"=>500,
                               "error"=>{"type" => "illegal_state_exception",
                                        "reason" => "pipeline with id [test-ingest] could not be loaded, caused by [ElasticsearchParseException[Error updating pipeline with id [test-ingest]]; nested: ElasticsearchException[java.lang.IllegalArgumentException: no enrich index exists for policy with name [test-metadata1]];"
                                        }
                              }
                    }]
        }
      end

      before(:each) do
        allow(subject.client).to receive(:bulk_send).with(instance_of(StringIO), instance_of(Array)) do |stream, actions|
          expect( stream.string ).to include '"foo":"bar1"'
          expect( stream.string ).to include '"foo":"bar2"'
        end.and_return(bulk_response, {"errors"=>false}) # let's make it go away (second call) to not retry indefinitely
      end

      it "should retry submit" do
        allow(subject.logger).to receive(:error).with(/Encountered an unexpected error/i, anything)
        allow(subject.client).to receive(:bulk).and_call_original # track count

        subject.multi_receive(events)

        expect(subject.client).to have_received(:bulk).twice
      end

      it "should log specific error message" do
        expect(subject.logger).to receive(:error).with(/Encountered an unexpected error/i,
                                                       hash_including(:message => 'Sent 2 documents but Elasticsearch returned 3 responses (likely a bug with _bulk endpoint)'))

        subject.multi_receive(events)
      end
    end
  end

  context '413 errors' do
    let(:payload_size) { LogStash::Outputs::ElasticSearch::TARGET_BULK_BYTES + 1024 }
    let(:event) { ::LogStash::Event.new("message" => ("a" * payload_size ) ) }

    let(:logger_stub) { double("logger").as_null_object }

    before(:each) do
      allow(elasticsearch_output_instance.client).to receive(:logger).and_return(logger_stub)

      allow(elasticsearch_output_instance.client).to receive(:bulk).and_call_original

      max_bytes = payload_size * 3 / 4 # ensure a failure first attempt
      allow(elasticsearch_output_instance.client.pool).to receive(:post) do |path, params, body|
        if body.length > max_bytes
          max_bytes *= 2 # ensure a successful retry
          double("Response", :code => 413, :body => "")
        else
          double("Response", :code => 200, :body => '{"errors":false,"items":[{"index":{"status":200,"result":"created"}}]}')
        end
      end
    end

    it 'retries the 413 until it goes away' do
      elasticsearch_output_instance.multi_receive([event])

      expect(elasticsearch_output_instance.client).to have_received(:bulk).twice
    end

    it 'logs about payload quantity and size' do
      elasticsearch_output_instance.multi_receive([event])

      expect(logger_stub).to have_received(:warn)
                                 .with(a_string_matching(/413 Payload Too Large/),
                                       hash_including(:action_count => 1, :content_length => a_value > 20_000_000))
    end
  end

  context "with timeout set" do
    let(:listener) { Flores::Random.tcp_listener }
    let(:port) { listener[2] }
    let(:options) do
      {
        "manage_template" => false,
        "hosts" => "localhost:#{port}",
        "timeout" => 0.1, # fast timeout
      }
    end

    before do
      # Expect a timeout to be logged.
      expect(subject.logger).to receive(:error).with(/Attempted to send a bulk request/i, anything).at_least(:once)
      expect(subject.client).to receive(:bulk).at_least(:twice).and_call_original
    end

    it "should fail after the timeout" do
      #pending("This is tricky now that we do healthchecks on instantiation")
      Thread.new { subject.multi_receive([LogStash::Event.new]) }

      # Allow the timeout to occur
      sleep 6
    end
  end

  describe "the action option" do

    context "with a sprintf action" do
      let(:options) { {"action" => "%{myactionfield}" } }

      let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }

      it "should interpolate the requested action value when creating an event_action_tuple" do
        expect(subject.send(:event_action_tuple, event).first).to eql("update")
      end
    end

    context "with a sprintf action equals to update" do
      let(:options) { {"action" => "%{myactionfield}", "upsert" => '{"message": "some text"}' } }

      let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }

      it "should obtain specific action's params from event_action_tuple" do
        expect(subject.send(:event_action_tuple, event)[1]).to include(:_upsert)
      end
    end

    context "with an invalid action" do
      let(:options) { {"action" => "SOME Garbaaage"} }
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call

      before { allow(subject).to receive(:finish_register) }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end
    end
  end

  describe "the pipeline option" do

    context "with a sprintf and set pipeline" do
      let(:options) { {"pipeline" => "%{pipeline}" } }

      let(:event) { LogStash::Event.new("pipeline" => "my-ingest-pipeline") }

      it "should interpolate the pipeline value and set it" do
        expect(subject.send(:event_action_tuple, event)[1]).to include(:pipeline => "my-ingest-pipeline")
      end
    end

    context "with a sprintf and empty pipeline" do
      let(:options) { {"pipeline" => "%{pipeline}" } }

      let(:event) { LogStash::Event.new("pipeline" => "") }

      it "should interpolate the pipeline value but not set it because it is empty" do
        expect(subject.send(:event_action_tuple, event)[1]).not_to include(:pipeline)
      end
    end
  end

  describe "SSL end to end" do
    let(:do_register) { false } # skip the register in the global before block, as is called here.

    before(:each) do
      stub_manticore_client!
      subject.register
    end

    shared_examples("an encrypted client connection") do
      it "should enable SSL in manticore" do
        expect(subject.client.pool.urls.map(&:scheme).uniq).to eql(['https'])
      end
    end


    context "With the 'ssl' option" do
      let(:options) { {"ssl" => true}}

      include_examples("an encrypted client connection")
    end

    context "With an https host" do
      let(:options) { {"hosts" => "https://localhost"} }
      include_examples("an encrypted client connection")
    end
  end

  describe "retry_on_conflict" do
    let(:num_retries) { 123 }
    let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }
    let(:options) { { 'retry_on_conflict' => num_retries } }

    context "with a regular index" do
      let(:options) { super().merge("action" => "index") }

      it "should not set the retry_on_conflict parameter when creating an event_action_tuple" do
        allow(subject.client).to receive(:maximum_seen_major_version).and_return(maximum_seen_major_version)
        action, params, event_data = subject.send(:event_action_tuple, event)
        expect(params).not_to include({subject.send(:retry_on_conflict_action_name) => num_retries})
      end
    end

    context "using a plain update" do
      let(:options) { super().merge("action" => "update", "retry_on_conflict" => num_retries, "document_id" => 1) }

      it "should set the retry_on_conflict parameter when creating an event_action_tuple" do
        action, params, event_data = subject.send(:event_action_tuple, event)
        expect(params).to include({subject.send(:retry_on_conflict_action_name) => num_retries})
      end
    end

    context "with a sprintf action that resolves to update" do
      let(:options) { super().merge("action" => "%{myactionfield}", "retry_on_conflict" => num_retries, "document_id" => 1) }

      it "should set the retry_on_conflict parameter when creating an event_action_tuple" do
        action, params, event_data = subject.send(:event_action_tuple, event)
        expect(params).to include({subject.send(:retry_on_conflict_action_name) => num_retries})
        expect(action).to eq("update")
      end
    end
  end

  describe "sleep interval calculation" do
    let(:retry_max_interval) { 64 }
    let(:options) { { "retry_max_interval" => retry_max_interval } }

    it "should double the given value" do
      expect(subject.next_sleep_interval(2)).to eql(4)
      expect(subject.next_sleep_interval(32)).to eql(64)
    end

    it "should not increase the value past the max retry interval" do
      sleep_interval = 2
      100.times do
        sleep_interval = subject.next_sleep_interval(sleep_interval)
        expect(sleep_interval).to be <= retry_max_interval
      end
    end
  end

  describe "stale connection check" do
    let(:validate_after_inactivity) { 123 }
    let(:options) { { "validate_after_inactivity" => validate_after_inactivity } }
    let(:do_register) { false }

    before :each do
      allow(subject).to receive(:finish_register)

      allow(::Manticore::Client).to receive(:new).with(any_args).and_call_original
    end

    after :each do
      subject.close
    end

    it "should set the correct http client option for 'validate_after_inactivity'" do
      subject.register
      expect(::Manticore::Client).to have_received(:new) do |options|
        expect(options[:check_connection_timeout]).to eq(validate_after_inactivity)
      end
    end
  end

  describe "custom parameters" do

    let(:manticore_urls) { subject.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    let(:custom_parameters_hash) { { "id" => 1, "name" => "logstash" } }
    let(:custom_parameters_query) { custom_parameters_hash.map {|k,v| "#{k}=#{v}" }.join("&") }

    let(:stub_http_client_pool!) do
      [:start_resurrectionist, :start_sniffer, :healthcheck!].each do |method|
        allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(method)
      end
    end

    context "using non-url hosts" do

      let(:options) {
        {
          "index" => "my-index",
          "hosts" => ["localhost:9202"],
          "path" => "some-path",
          "parameters" => custom_parameters_hash
        }
      }

      it "creates a URI with the added parameters" do
        expect(subject.parameters).to eql(custom_parameters_hash)
      end

      it "sets the query string on the HTTP client" do
        expect(manticore_url.query).to eql(custom_parameters_query)
      end
    end

    context "using url hosts" do

      context "with embedded query parameters" do
        let(:options) {
          { "hosts" => ["http://localhost:9202/path?#{custom_parameters_query}"] }
        }

        it "sets the query string on the HTTP client" do
          expect(manticore_url.query).to eql(custom_parameters_query)
        end
      end

      context "with explicit query parameters" do
        let(:options) {
          {
            "hosts" => ["http://localhost:9202/path"],
            "parameters" => custom_parameters_hash
          }
        }

        it "sets the query string on the HTTP client" do
          expect(manticore_url.query).to eql(custom_parameters_query)
        end
      end

      context "with explicit query parameters and existing url parameters" do
        let(:existing_query_string) { "existing=param" }
        let(:options) {
          {
            "hosts" => ["http://localhost:9202/path?#{existing_query_string}"],
            "parameters" => custom_parameters_hash
          }
        }

        it "keeps the existing query string" do
          expect(manticore_url.query).to include(existing_query_string)
        end

        it "includes the new query string" do
          expect(manticore_url.query).to include(custom_parameters_query)
        end

        it "appends the new query string to the existing one" do
          expect(manticore_url.query).to eql("#{existing_query_string}&#{custom_parameters_query}")
        end
      end
    end
  end

  describe "cloud.id" do
    let(:do_register) { false }

    let(:valid_cloud_id) do
      'sample:dXMtY2VudHJhbDEuZ2NwLmNsb3VkLmVzLmlvJGFjMzFlYmI5MDI0MTc3MzE1NzA0M2MzNGZkMjZmZDQ2OjkyNDMkYTRjMDYyMzBlNDhjOGZjZTdiZTg4YTA3NGEzYmIzZTA6OTI0NA=='
    end

    let(:options) { { 'cloud_id' => valid_cloud_id } }

    before(:each) do
      stub_manticore_client!
    end

    it "should set host(s)" do
      subject.register
      es_url = subject.client.pool.urls.first
      expect( es_url.to_s ).to eql('https://ac31ebb90241773157043c34fd26fd46.us-central1.gcp.cloud.es.io:9243/')
    end

    context 'invalid' do
      let(:options) { { 'cloud_id' => 'invalid:dXMtY2VudHJhbDEuZ2NwLmNsb3VkLmVzLmlv' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /cloud_id.*? is invalid/
      end
    end

    context 'hosts also set' do
      let(:options) { { 'cloud_id' => valid_cloud_id, 'hosts' => [ 'localhost' ] } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /cloud_id and hosts/
      end
    end
  end if LOGSTASH_VERSION > '6.0'

  describe "cloud.auth" do
    let(:do_register) { false }

    let(:options) { { 'cloud_auth' => LogStash::Util::Password.new('elastic:my-passwd-00') } }

    before(:each) do
      stub_manticore_client!
    end

    it "should set host(s)" do
      subject.register
      es_url = subject.client.pool.urls.first
      expect( es_url.user ).to eql('elastic')
      expect( es_url.password ).to eql('my-passwd-00')
    end

    context 'invalid' do
      let(:options) { { 'cloud_auth' => 'invalid-format' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /cloud_auth.*? format/
      end
    end

    context 'user also set' do
      let(:options) { { 'cloud_auth' => 'elastic:my-passwd-00', 'user' => 'another' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
      end
    end

    context 'api_key also set' do
      let(:options) { { 'cloud_auth' => 'elastic:my-passwd-00', 'api_key' => 'some_key' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
      end
    end
  end if LOGSTASH_VERSION > '6.0'

  context 'handling elasticsearch document-level status meant for the DLQ' do
    let(:options) { { "manage_template" => false } }

    context 'when @dlq_writer is nil' do
      before { subject.instance_variable_set '@dlq_writer', nil }

      context 'resorting to previous behaviour of logging the error' do
        context 'getting an invalid_index_name_exception' do
          it 'should log at ERROR level' do
            subject.instance_variable_set(:@logger, double("logger").as_null_object)
            mock_response = { 'index' => { 'error' => { 'type' => 'invalid_index_name_exception' } } }
            subject.handle_dlq_status("Could not index event to Elasticsearch.",
              [:action, :params, :event], :some_status, mock_response)
          end
        end

        context 'when getting any other exception' do
          it 'should log at WARN level' do
            logger = double("logger").as_null_object
            subject.instance_variable_set(:@logger, logger)
            expect(logger).to receive(:warn).with(/Could not index/, hash_including(:status, :action, :response))
            mock_response = { 'index' => { 'error' => { 'type' => 'illegal_argument_exception' } } }
            subject.handle_dlq_status("Could not index event to Elasticsearch.",
              [:action, :params, :event], :some_status, mock_response)
          end
        end

        context 'when the response does not include [error]' do
          it 'should not fail, but just log a warning' do
            logger = double("logger").as_null_object
            subject.instance_variable_set(:@logger, logger)
            expect(logger).to receive(:warn).with(/Could not index/, hash_including(:status, :action, :response))
            mock_response = { 'index' => {} }
            expect do
              subject.handle_dlq_status("Could not index event to Elasticsearch.",
                [:action, :params, :event], :some_status, mock_response)
            end.to_not raise_error
          end
        end
      end
    end

    # DLQ writer always nil, no matter what I try here. So mocking it all the way
    context 'when DLQ is enabled' do
      let(:dlq_writer) { double('DLQ writer') }
      before { subject.instance_variable_set('@dlq_writer', dlq_writer) }

      # Note: This is not quite the desired behaviour.
      # We should still log when sending to the DLQ.
      # This shall be solved by another issue, however: logstash-output-elasticsearch#772
      it 'should send the event to the DLQ instead, and not log' do
        event = LogStash::Event.new("foo" => "bar")
        expect(dlq_writer).to receive(:write).once.with(event, /Could not index/)
        mock_response = { 'index' => { 'error' => { 'type' => 'illegal_argument_exception' } } }
        action = LogStash::Outputs::ElasticSearch::EventActionTuple.new(:action, :params, event)
        subject.handle_dlq_status("Could not index event to Elasticsearch.", action, 404, mock_response)
      end
    end

    context 'with error response status' do

      let(:options) { super().merge 'document_id' => '%{foo}' }

      let(:events) { [ LogStash::Event.new("foo" => "bar") ] }

      let(:dlq_writer) { subject.instance_variable_get(:@dlq_writer) }

      let(:error_code) { 400 }

      let(:bulk_response) do
        {
            "took"=>1, "ingest_took"=>11, "errors"=>true, "items"=>
            [{
                 "index"=>{"_index"=>"bar", "_type"=>"_doc", "_id"=>'bar', "status" => error_code,
                           "error"=>{"type" => "illegal_argument_exception", "reason" => "TEST" }
                  }
            }]
        }
      end

      before(:each) do
        allow(subject.client).to receive(:bulk_send).and_return(bulk_response)
      end

      shared_examples "should write event to DLQ" do
        it "should write event to DLQ" do
          expect(dlq_writer).to receive(:write).and_wrap_original do |method, *args|
            expect( args.size ).to eql 2

            event, reason = *args
            expect( event ).to be_a LogStash::Event
            expect( event ).to be events.first
            expect( reason ).to start_with "Could not index event to Elasticsearch. status: #{error_code}, action: [\"index\""
            expect( reason ).to match /_id=>"bar".*"foo"=>"bar".*response:.*"reason"=>"TEST"/

            method.call(*args) # won't hurt to call LogStash::Util::DummyDeadLetterQueueWriter
          end.once

          event_action_tuples = subject.map_events(events)
          subject.send(:submit, event_action_tuples)
        end
      end

      context "is one of the predefined codes" do
        include_examples "should write event to DLQ"
      end

      context "when user customized dlq_custom_codes option" do
        let(:error_code) { 403 }
        let(:options) { super().merge 'dlq_custom_codes' => [error_code] }

        include_examples "should write event to DLQ"
      end

    end if LOGSTASH_VERSION > '7.0'
  end

  describe "custom headers" do
    let(:manticore_options) { subject.client.pool.adapter.manticore.instance_variable_get(:@options) }

    context "when set" do
      let(:headers) { { "X-Thing" => "Test" } }
      let(:options) { { "custom_headers" => headers } }
      it "should use the custom headers in the adapter options" do
        expect(manticore_options[:headers]).to eq(headers)
      end
    end

    context "when not set" do
      it "should have no headers" do
        expect(manticore_options[:headers]).to be_empty
      end
    end
  end

  describe "API key" do
    let(:manticore_options) { subject.client.pool.adapter.manticore.instance_variable_get(:@options) }
    let(:api_key) { "some_id:some_api_key" }
    let(:base64_api_key) { "ApiKey c29tZV9pZDpzb21lX2FwaV9rZXk=" }

    context "when set without ssl" do
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
      let(:options) { { "api_key" => api_key } }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /requires SSL\/TLS/
      end
    end

    context "when set without ssl but with a https host" do
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
      let(:options) { { "hosts" => ["https://some.host.com"], "api_key" => api_key } }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /requires SSL\/TLS/
      end
    end

    context "when set" do
      let(:options) { { "ssl" => true, "api_key" =>  ::LogStash::Util::Password.new(api_key) } }

      it "should use the custom headers in the adapter options" do
        expect(manticore_options[:headers]).to eq({ "Authorization" => base64_api_key })
      end
    end

    context "when not set" do
      it "should have no headers" do
        expect(manticore_options[:headers]).to be_empty
      end
    end

    context 'user also set' do
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
      let(:options) { { "ssl" => true, "api_key" => api_key, 'user' => 'another' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
      end
    end

    context 'cloud_auth also set' do
      let(:do_register) { false } # this is what we want to test, so we disable the before(:each) call
      let(:options) { { "ssl" => true, "api_key" => api_key, 'cloud_auth' => 'foobar' } }

      it "should fail" do
        expect { subject.register }.to raise_error LogStash::ConfigurationError, /Multiple authentication options are specified/
      end
    end
  end

  describe 'ECS Compatibility Support', :ecs_compatibility_support do
    [
      :disabled,
      :v1,
      :v8,
    ].each do |ecs_compatibility|
      context "When initialized with `ecs_compatibility => #{ecs_compatibility}`" do
        let(:options) { Hash.new }
        subject(:output) { described_class.new(options.merge("ecs_compatibility" => "#{ecs_compatibility}")) }
        context 'when registered' do
          before(:each) { output.register }
          it 'has the correct effective ECS compatibility setting' do
            expect(output.ecs_compatibility).to eq(ecs_compatibility)
          end
        end
      end
    end
  end

  describe "post-register ES setup" do
    let(:do_register) { false }
    let(:es_version) { '7.10.0' } # DS default on LS 8.x
    let(:options) { { 'hosts' => '127.0.0.1:9999' } }
    let(:logger) { subject.logger }

    before do
      allow(logger).to receive(:error) # expect tracking

      allow(subject).to receive(:last_es_version).and_return es_version
      # make successful_connection? return true:
      allow(subject).to receive(:maximum_seen_major_version).and_return Integer(es_version.split('.').first)
      allow(subject).to receive(:alive_urls_count).and_return Integer(1)
      allow(subject).to receive(:stop_after_successful_connection_thread)
    end

    it "logs inability to retrieve uuid" do
      allow(subject).to receive(:install_template)
      allow(subject).to receive(:ilm_in_use?).and_return nil
      subject.register
      subject.send :wait_for_successful_connection

      expect(logger).to have_received(:error).with(/Unable to retrieve Elasticsearch cluster uuid/i, anything)
    end if LOGSTASH_VERSION >= '7.0.0'

    it "logs template install failure" do
      allow(subject).to receive(:discover_cluster_uuid)
      allow(subject).to receive(:ilm_in_use?).and_return nil
      subject.register
      subject.send :wait_for_successful_connection

      expect(logger).to have_received(:error).with(/Failed to install template/i, anything)
    end

    context 'error raised' do

      let(:es_version) { '7.8.0' }
      let(:options) { super().merge('data_stream' => 'true', 'ecs_compatibility' => 'v1') }
      let(:latch) { Concurrent::CountDownLatch.new }

      before do
        allow(subject).to receive(:install_template)
        allow(subject).to receive(:discover_cluster_uuid)
        allow(subject).to receive(:ilm_in_use?).and_return nil
        # executes from the after_successful_connection thread :
        allow(subject).to receive(:finish_register) { latch.wait }.and_call_original
        subject.register
      end

      it 'keeps logging on multi_receive' do
        allow(subject).to receive(:retrying_submit)
        latch.count_down; sleep(1.0)

        expect_logged_error = lambda do |count|
          expect(logger).to have_received(:error).with(
              /Elasticsearch setup did not complete normally, please review previously logged errors/i,
              hash_including(message:  'A data_stream configuration is only supported since Elasticsearch 7.9.0 (detected version 7.8.0), please upgrade your cluster')
          ).exactly(count).times
        end

        subject.multi_receive [ LogStash::Event.new('foo' => 1) ]
        expect_logged_error.call(1)

        subject.multi_receive [ LogStash::Event.new('foo' => 2) ]
        expect_logged_error.call(2)
      end

    end
  end

  @private

  def stub_manticore_client!(manticore_double = nil)
    manticore_double ||= double("manticore #{self.inspect}")
    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:close)

    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)
  end

end
