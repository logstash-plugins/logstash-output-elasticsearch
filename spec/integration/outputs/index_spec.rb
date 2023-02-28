require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"
require 'cgi'

describe "TARGET_BULK_BYTES", :integration => true do
  let(:target_bulk_bytes) { LogStash::Outputs::ElasticSearch::TARGET_BULK_BYTES }
  let(:event_count) { 1000 }
  let(:events) { event_count.times.map { event }.to_a }
  let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
  }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { ESHelper.es_version_satisfies?("< 7") ? "doc" : "_doc" }

  subject { LogStash::Outputs::ElasticSearch.new(config) }

  before do
    subject.register
    allow(subject.client).to receive(:bulk_send).with(any_args).and_call_original
    subject.multi_receive(events)
  end

  describe "batches that are too large for one" do
    let(:event) { LogStash::Event.new("message" => "a " * (((target_bulk_bytes/2) / event_count)+1)) }

    it "should send in two batches" do
      expect(subject.client).to have_received(:bulk_send).twice do |payload|
        expect(payload.size).to be <= target_bulk_bytes
      end
    end

    describe "batches that fit in one" do
      # Normally you'd want to generate a request that's just 1 byte below the limit, but it's
      # impossible to know how many bytes an event will serialize as with bulk proto overhead
      let(:event) { LogStash::Event.new("message" => "a") }

      it "should send in one batch" do
        expect(subject.client).to have_received(:bulk_send).once do |payload|
          expect(payload.size).to be <= target_bulk_bytes
        end
      end
    end
  end
end

def curl_and_get_json_response(url, method: :get, retrieve_err_payload: false); require 'open3'
  cmd = "curl -s -v --show-error #{curl_opts} -X #{method.to_s.upcase} -k #{url}"
  begin
    out, err, status = Open3.capture3(cmd)
  rescue Errno::ENOENT
    fail "curl not available, make sure curl binary is installed and available on $PATH"
  end

  if status.success?
    http_status = err.match(/< HTTP\/1.1 (\d+)/)[1] || '0' # < HTTP/1.1 200 OK\r\n

    if http_status.strip[0].to_i > 2
      error = (LogStash::Json.load(out)['error']) rescue nil
      if error
        if retrieve_err_payload
          return error
        else
          fail "#{cmd.inspect} received an error: #{http_status}\n\n#{error.inspect}"
        end
      else
        warn out
        fail "#{cmd.inspect} unexpected response: #{http_status}\n\n#{err}"
      end
    end

    LogStash::Json.load(out)
  else
    warn out
    fail "#{cmd.inspect} process failed: #{status}\n\n#{err}"
  end
end

describe "indexing with sprintf resolution", :integration => true do
  let(:message) { "Hello from #{__FILE__}" }
  let(:event) { LogStash::Event.new("message" => message, "type" => type) }
  let (:index) { "%{[index_name]}_dynamic" }
  let(:type) { ESHelper.es_version_satisfies?("< 7") ? "doc" : "_doc" }
  let(:event_count) { 1 }
  let(:user) { "simpleuser" }
  let(:password) { "abc123" }
  let(:config) do
    {
      "hosts" => [ get_host_port ],
      "user" => user,
      "password" => password,
      "index" => index
    }
  end
  let(:events) { event_count.times.map { event }.to_a }
  subject { LogStash::Outputs::ElasticSearch.new(config) }

  let(:es_url) { "http://#{get_host_port}" }
  let(:index_url) { "#{es_url}/#{index}" }

  let(:curl_opts) { nil }

  let(:es_admin) { 'admin' } # default user added in ES -> 8.x requires auth credentials for /_refresh etc
  let(:es_admin_pass) { 'elastic' }

  let(:initial_events) { [] }

  let(:do_register) { true }

  before do
    subject.register if do_register
    subject.multi_receive(initial_events) if initial_events
  end

  after do
    subject.do_close
  end

  let(:event) { LogStash::Event.new("message" => message, "type" => type, "index_name" => "test") }

  it "should index successfully when field is resolved" do
    expected_index_name = "test_dynamic"
    subject.multi_receive(events)

#     curl_and_get_json_response "#{es_url}/_refresh", method: :post

    result = curl_and_get_json_response "#{es_url}/#{expected_index_name}"

    expect(result[expected_index_name]).not_to be(nil)
  end

  context "when dynamic field doesn't resolve the index_name" do
    let(:event) { LogStash::Event.new("message" => message, "type" => type) }
    let(:dlq_writer) { double('DLQ writer') }
    before { subject.instance_variable_set('@dlq_writer', dlq_writer) }

    it "should doesn't create an index name with unresolved placeholders" do
      expect(dlq_writer).to receive(:write).once.with(event, a_string_including("Badly formatted index, after interpolation still contains placeholder"))
      subject.multi_receive(events)

      escaped_index_name = CGI.escape("%{[index_name]}_dynamic")
      result = curl_and_get_json_response "#{es_url}/#{escaped_index_name}", retrieve_err_payload: true
      expect(result["root_cause"].first()["type"]).to eq("index_not_found_exception")
    end
  end
end

describe "indexing" do
  let(:message) { "Hello from #{__FILE__}" }
  let(:event) { LogStash::Event.new("message" => message, "type" => type) }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { ESHelper.es_version_satisfies?("< 7") ? "doc" : "_doc" }
  let(:event_count) { 1 + rand(2) }
  let(:config) { "not implemented" }
  let(:events) { event_count.times.map { event }.to_a }
  subject { LogStash::Outputs::ElasticSearch.new(config) }
  
  let(:es_url) { "http://#{get_host_port}" }
  let(:index_url) { "#{es_url}/#{index}" }

  let(:curl_opts) { nil }

  let(:es_admin) { 'admin' } # default user added in ES -> 8.x requires auth credentials for /_refresh etc
  let(:es_admin_pass) { 'elastic' }

  let(:initial_events) { [] }

  let(:do_register) { true }

  before do
    subject.register if do_register
    subject.multi_receive(initial_events) if initial_events
  end

  after do
    subject.do_close
  end

  shared_examples "an indexer" do |secure|
    before(:each) do
      host_unreachable_error_class = LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError
      allow(host_unreachable_error_class).to receive(:new).with(any_args).and_wrap_original do |m, original, url|
        if original.message.include?("PKIX path building failed")
          $stderr.puts "Client not connecting due to PKIX path building failure; " +
                         "shutting plugin down to prevent infinite retries"
          subject.close # premature shutdown to prevent infinite retry
        end
        m.call(original, url)
      end
    end

    it "ships events" do
      subject.multi_receive(events)

      curl_and_get_json_response "#{es_url}/_refresh", method: :post

      result = curl_and_get_json_response "#{index_url}/_count?q=*"
      cur_count = result["count"]
      expect(cur_count).to eq(event_count)

      result = curl_and_get_json_response "#{index_url}/_search?q=*&size=1000"
      result["hits"]["hits"].each do |doc|
        expect(doc["_source"]["message"]).to eq(message)

        if ESHelper.es_version_satisfies?("< 8")
          expect(doc["_type"]).to eq(type)
        else
          expect(doc).not_to include("_type")
        end
        expect(doc["_index"]).to eq(index)
      end
    end
    
    it "sets the correct content-type header" do
      expected_manticore_opts = {:headers => {"Content-Type" => "application/json"}, :body => anything}
      if secure
        expected_manticore_opts = {
          :headers => {"Content-Type" => "application/json"}, 
          :body => anything, 
          :auth => {
            :user => user,
            :password => password,
            :eager => true
          }}
      end
      expect(subject.client.pool.adapter.client).to receive(:send).
        with(anything, anything, expected_manticore_opts).at_least(:once).
        and_call_original
      subject.multi_receive(events)
    end
  end

  shared_examples "PKIX path failure" do
    let(:do_register) { false }
    let(:host_unreachable_error_class) { LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError }

    before(:each) do
      limit_execution
    end

    let(:limit_execution) do
      Thread.new { sleep 5; subject.close }
    end

    it 'fails to establish TLS' do
      allow(host_unreachable_error_class).to receive(:new).with(any_args).and_call_original.at_least(:once)

      subject.register
      limit_execution.join

      sleep 1

      expect(host_unreachable_error_class).to have_received(:new).at_least(:once) do |original, url|
        expect(original.message).to include("PKIX path building failed")
      end
    end
  end

  describe "an indexer with custom index_type", :integration => true do
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    it_behaves_like("an indexer")
  end

  describe "an indexer with no type value set (default to doc)", :integration => true do
    let(:type) { ESHelper.es_version_satisfies?("< 7") ? "doc" : "_doc" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    it_behaves_like("an indexer")
  end

  describe "a secured indexer", :secure_integration => true do
    let(:user) { "simpleuser" }
    let(:password) { "abc123" }
    let(:cacert) { "spec/fixtures/test_certs/ca.crt" }
    let(:es_url) { "https://#{get_host_port}" }
    let(:config) do
      {
        "hosts" => [ get_host_port ],
        "user" => user,
        "password" => password,
        "ssl_enabled" => true,
        "ssl_certificate_authorities" => cacert,
        "index" => index
      }
    end 

    let(:curl_opts) { "-u #{user}:#{password}" }

    if ENV['ES_SSL_KEY_INVALID'] == 'true' # test_invalid.crt (configured in ES) has SAN: DNS:localhost
      # javax.net.ssl.SSLPeerUnverifiedException: Host name 'elasticsearch' does not match the certificate subject ...

      context "when no keystore nor ca cert set and verification is disabled" do
        let(:config) do
          super().tap { |config| config.delete('ssl_certificate_authorities') }.merge('ssl_verification_mode' => 'none')
        end

        include_examples("an indexer", true)
      end

      context "when keystore is set and verification is disabled" do
        let(:config) do
          super().merge(
              'ssl_verification_mode' => 'none',
              'ssl_keystore_path' => 'spec/fixtures/test_certs/test.p12',
              'ssl_keystore_password' => '1234567890'
          )
        end

        include_examples("an indexer", true)
      end

      context "when keystore has self-signed cert and verification is disabled" do
        let(:config) do
          super().tap { |config| config.delete('ssl_certificate_authorities') }.merge(
              'ssl_verification_mode' => 'none',
              'ssl_keystore_path' => 'spec/fixtures/test_certs/test_self_signed.p12',
              'ssl_keystore_password' => '1234567890'
          )
        end

        include_examples("an indexer", true)
      end

    else

      let(:curl_opts) { "#{super()} --tlsv1.2 --tls-max 1.3 -u #{es_admin}:#{es_admin_pass}" } # due ES 8.x we need user/password

      it_behaves_like("an indexer", true)

      describe "with a password requiring escaping" do
        let(:user) { "f@ncyuser" }
        let(:password) { "ab%12#" }

        include_examples("an indexer", true)
      end

      describe "with a user/password requiring escaping in the URL" do
        let(:config) do
          {
              "hosts" => ["https://#{CGI.escape(user)}:#{CGI.escape(password)}@elasticsearch:9200"],
              "ssl_enabled" => true,
              "ssl_certificate_authorities" => "spec/fixtures/test_certs/test.crt",
              "index" => index
          }
        end

        include_examples("an indexer", true)
      end

      context "without providing `ssl_certificate_authorities`" do
        let(:config) do
          super().tap do |c|
            c.delete("ssl_certificate_authorities")
          end
        end

        it_behaves_like("PKIX path failure")
      end

      if Gem::Version.new(LOGSTASH_VERSION) >= Gem::Version.new("8.3.0")
        context "with `ca_trusted_fingerprint` instead of `ssl_certificate_authorities`" do
          let(:config) do
            super().tap do |c|
              c.delete("ssl_certificate_authorities")
              c.update("ca_trusted_fingerprint" => ca_trusted_fingerprint)
            end
          end
          let(:ca_trusted_fingerprint) { File.read("spec/fixtures/test_certs/test.der.sha256").chomp }


          it_behaves_like("an indexer", true)

          context 'with an invalid `ca_trusted_fingerprint`' do
            let(:ca_trusted_fingerprint) { super().reverse }

            it_behaves_like("PKIX path failure")
          end
        end
      end

      context 'with enforced TLSv1.3 protocol' do
        let(:config) { super().merge 'ssl_supported_protocols' => [ 'TLSv1.3' ] }

        it_behaves_like("an indexer", true)
      end

      context 'with enforced TLSv1.2 protocol (while ES only enabled TLSv1.3)' do
        let(:config) { super().merge 'ssl_supported_protocols' => [ 'TLSv1.2' ] }

        let(:initial_events) { nil }

        it "does not ship events" do
          curl_and_get_json_response index_url, method: :put # make sure index exists
          Thread.start { subject.multi_receive(events) } # we'll be stuck in a retry loop
          sleep 2.5

          curl_and_get_json_response "#{es_url}/_refresh", method: :post

          result = curl_and_get_json_response "#{index_url}/_count?q=*"
          cur_count = result["count"]
          expect(cur_count).to eq(0) # ES output keeps re-trying but ends up with a
          # [Manticore::ClientProtocolException] Received fatal alert: protocol_version
        end

      end if ENV['ES_SSL_SUPPORTED_PROTOCOLS'] == 'TLSv1.3'

    end

  end
end
