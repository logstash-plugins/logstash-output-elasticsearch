require_relative "../../../spec/es_spec_helper"
require "flores/random"
require "logstash/outputs/elasticsearch"

describe "outputs/elasticsearch" do
  context "with an active instance" do
    let(:options) {
      {
        "index" => "my-index",
        "hosts" => ["localhost","localhost:9202"],
        "path" => "some-path",
        "manage_template" => false
      }
    }
    
    let(:eso) { LogStash::Outputs::ElasticSearch.new(options) }

    let(:manticore_urls) { eso.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    let(:do_register) { true }

    before(:each) do
      if do_register
        eso.register
        
        # Rspec mocks can't handle background threads, so... we can't use any 
        allow(eso.client.pool).to receive(:start_resurrectionist)
        allow(eso.client.pool).to receive(:start_sniffer)
        allow(eso.client.pool).to receive(:healthcheck!)
        eso.client.pool.adapter.manticore.respond_with(:body => "{}")
      end
    end
    
    after(:each) do
      eso.close 
    end
    
    describe "getting a document type" do
      it "should default to 'logs'" do
        expect(eso.send(:get_event_type, LogStash::Event.new)).to eql("logs")
      end

      it "should get the type from the event if nothing else specified in the config" do
        expect(eso.send(:get_event_type, LogStash::Event.new("type" => "foo"))).to eql("foo")
      end

      context "with 'document type set'" do
        let(:options) { super.merge("document_type" => "bar")}
        it "should get the event type from the 'document_type' setting" do
          expect(eso.send(:get_event_type, LogStash::Event.new())).to eql("bar")
        end
      end

      context "with a bad type" do
        let(:type_arg) { ["foo"] }
        let(:result) { eso.send(:get_event_type, LogStash::Event.new("type" => type_arg)) }

        before do
          allow(eso.instance_variable_get(:@logger)).to receive(:warn)
          result
        end

        it "should call @logger.warn and return nil" do
          expect(eso.instance_variable_get(:@logger)).to have_received(:warn).with(/Bad event type!/, anything).once
        end

        it "should set the type to the stringified value" do
          expect(result).to eql(type_arg.to_s)
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
          super.merge("hosts" => ["http://#{user}:#{password.value}@localhost:9200"])
        }
        
        include_examples("an authenticated config")
      end
      
      context "as a hash option" do
          let(:options) {
            super.merge!(
              "user" => user,
              "password" => password
            )
        }
        
        include_examples("an authenticated config")
      end
    end

    describe "with path" do
      it "should properly create a URI with the path" do
        expect(eso.path).to eql(options["path"])
      end

        it "should properly set the path on the HTTP client adding slashes" do
        expect(manticore_url.path).to eql("/" + options["path"] + "/")
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:options) { super.merge("path" => "/some-path/") }

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
          expect { eso }.not_to raise_error
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
            expect { eso }.not_to raise_error
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
            expect { eso.register }.to raise_error(LogStash::ConfigurationError)
          end
        end
      end
    end

    describe "without a port specified" do
      it "should properly set the default port (9200) on the HTTP client" do
        expect(manticore_url.port).to eql(9200)
      end
    end
    describe "with a port other than 9200 specified" do
      it "should properly set the specified port on the HTTP client" do
        expect(manticore_urls.any? {|u| u.port == 9202}).to eql(true)
      end
    end

    describe "#multi_receive" do
      let(:events) { [double("one"), double("two"), double("three")] }
      let(:events_tuples) { [double("one t"), double("two t"), double("three t")] }
      let(:options) { super.merge("flush_size" => 2) }

      before do
        allow(eso).to receive(:retrying_submit).with(anything)
        events.each_with_index do |e,i|
          et = events_tuples[i]
          allow(eso).to receive(:event_action_tuple).with(e).and_return(et)
        end
        eso.multi_receive(events)
      end

      it "should receive an array of events and invoke retrying_submit with them, split by flush_size" do
        expect(eso).to have_received(:retrying_submit).with(events_tuples.slice(0,2))
        expect(eso).to have_received(:retrying_submit).with(events_tuples.slice(2,3))
      end

    end

  end

  context "with timeout set" do
    let(:listener) { Flores::Random.tcp_listener }
    let(:port) { listener[2] }
    let(:options) do
      {
        "manage_template" => false,
        "hosts" => "localhost:#{port}",
        "flush_size" => 1,
        "timeout" => 0.1, # fast timeout
      }
    end
    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}

    before do
      eso.register

      # Expect a timeout to be logged.
      expect(eso.logger).to receive(:error).with(/Attempted to send a bulk request to Elasticsearch/i, anything).at_least(:once)
      expect(eso.client).to receive(:bulk).at_least(:twice).and_call_original
    end

    it "should fail after the timeout" do
      #pending("This is tricky now that we do healthchecks on instantiation")
      Thread.new { eso.multi_receive([LogStash::Event.new]) }

      # Allow the timeout to occur
      sleep 6
    end
  end

  describe "the action option" do
    subject(:eso) {LogStash::Outputs::ElasticSearch.new(options)}
    context "with a sprintf action" do
      let(:options) { {"action" => "%{myactionfield}"} }

      let(:event) { LogStash::Event.new("myactionfield" => "update", "message" => "blah") }

      it "should interpolate the requested action value when creating an event_action_tuple" do
        expect(eso.event_action_tuple(event).first).to eql("update")
      end
    end

    context "with an invalid action" do
      let(:options) { {"action" => "SOME Garbaaage"} }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end
    end
  end

  describe "SSL end to end" do
    let(:manticore_double) do 
      double("manticoreX#{self.inspect}") 
    end
    
    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}

    before(:each) do
      response_double = double("manticore response").as_null_object
      # Allow healtchecks
      allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
      allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
      allow(manticore_double).to receive(:close)
        
      allow(::Manticore::Client).to receive(:new).and_return(manticore_double)
      eso.register
    end
    
    after(:each) do
      eso.close
    end
    
    
    shared_examples("an encrypted client connection") do
      it "should enable SSL in manticore" do
        expect(eso.client.pool.urls.map(&:scheme).uniq).to eql(['https'])
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
    let(:event) { LogStash::Event.new("message" => "blah") }
    subject(:eso) {LogStash::Outputs::ElasticSearch.new(options.merge('retry_on_conflict' => num_retries))}

    context "with a regular index" do
      let(:options) { {"action" => "index"} }

      it "should interpolate the requested action value when creating an event_action_tuple" do
        action, params, event_data = eso.event_action_tuple(event)
        expect(params).not_to include({:_retry_on_conflict => num_retries})
      end
    end

    context "using a plain update" do
      let(:options) { {"action" => "update", "retry_on_conflict" => num_retries} }

      it "should interpolate the requested action value when creating an event_action_tuple" do
        action, params, event_data = eso.event_action_tuple(event)
        expect(params).to include({:_retry_on_conflict => num_retries})
      end
    end
  end

  describe "sleep interval calculation" do
    let(:retry_max_interval) { 64 }
    subject(:eso) { LogStash::Outputs::ElasticSearch.new("retry_max_interval" => retry_max_interval) }

    it "should double the given value" do
      expect(eso.next_sleep_interval(2)).to eql(4)
      expect(eso.next_sleep_interval(32)).to eql(64)
    end

    it "should not increase the value past the max retry interval" do
      sleep_interval = 2
      100.times do
        sleep_interval = eso.next_sleep_interval(sleep_interval)
        expect(sleep_interval).to be <= retry_max_interval
      end
    end
  end

  describe "stale connection check" do
    let(:validate_after_inactivity) { 123 }
    subject(:eso) { LogStash::Outputs::ElasticSearch.new("validate_after_inactivity" => validate_after_inactivity) }

    before do
      allow(::Manticore::Client).to receive(:new).with(any_args).and_call_original
      subject.register
    end

    it "should set the correct http client option for 'validate_after_inactivity" do
      expect(::Manticore::Client).to have_received(:new) do |options|
        expect(options[:check_connection_timeout]).to eq(validate_after_inactivity)
      end
    end
  end

  describe "custom parameters" do

    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}

    let(:manticore_urls) { eso.client.pool.urls }
    let(:manticore_url) { manticore_urls.first }

    let(:custom_parameters_hash) { { "id" => 1, "name" => "logstash" } }
    let(:custom_parameters_query) { custom_parameters_hash.map {|k,v| "#{k}=#{v}" }.join("&") }

    before(:each) do
      eso.register
    end

    after(:each) do
      eso.close rescue nil
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
        expect(eso.parameters).to eql(custom_parameters_hash)
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

      context "with explicity query parameters" do
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

      context "with explicity query parameters and existing url parameters" do
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

  context "for safety" do
    context "when the password is 'changeme'" do
      let(:config) do
        {
          "user" => "elastic",
          "password" => "changeme"
        }
      end

      subject { LogStash::Outputs::ElasticSearch.new(config) }

      it "the configuration should be rejected" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, /changeme/)
      end
    end
  end
end
