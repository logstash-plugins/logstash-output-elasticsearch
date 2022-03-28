require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"

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

  def curl_and_get_json_response(url, method: :get); require 'open3'
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
          fail "#{cmd.inspect} received an error: #{http_status}\n\n#{error.inspect}"
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

  let(:initial_events) { [] }

  before do
    subject.register
    subject.multi_receive(initial_events) if initial_events
  end

  after do
    subject.do_close
  end

  shared_examples "an indexer" do |secure|
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
        "ssl" => true,
        "cacert" => cacert,
        "index" => index
      }
    end 

    let(:curl_opts) { "-u #{user}:#{password}" }

    if ENV['ES_SSL_KEY_INVALID'] == 'true' # test_invalid.crt (configured in ES) has SAN: DNS:localhost
      # javax.net.ssl.SSLPeerUnverifiedException: Host name 'elasticsearch' does not match the certificate subject ...

      context "when no keystore nor ca cert set and verification is disabled" do
        let(:config) do
          super().tap { |config| config.delete('cacert') }.merge('ssl_certificate_verification' => false)
        end

        include_examples("an indexer", true)
      end

      context "when keystore is set and verification is disabled" do
        let(:config) do
          super().merge(
              'ssl_certificate_verification' => false,
              'keystore' => 'spec/fixtures/test_certs/test.p12',
              'keystore_password' => '1234567890'
          )
        end

        include_examples("an indexer", true)
      end

      context "when keystore has self-signed cert and verification is disabled" do
        let(:config) do
          super().tap { |config| config.delete('cacert') }.merge(
              'ssl_certificate_verification' => false,
              'keystore' => 'spec/fixtures/test_certs/test_self_signed.p12',
              'keystore_password' => '1234567890'
          )
        end

        include_examples("an indexer", true)
      end

    else

      let(:curl_opts) { "#{super()} --tlsv1.2 --tls-max 1.3" }

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
              "ssl" => true,
              "cacert" => "spec/fixtures/test_certs/test.crt",
              "index" => index
          }
        end

        include_examples("an indexer", true)
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
