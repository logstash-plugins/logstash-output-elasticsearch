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
  let(:type) { 10.times.collect { rand(10).to_s }.join("") }
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
  let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
  let(:index) { 10.times.collect { rand(10).to_s }.join("") }
  let(:type) { 10.times.collect { rand(10).to_s }.join("") }
  let(:event_count) { 1 + rand(2) }
  let(:config) { "not implemented" }
  let(:events) { event_count.times.map { event }.to_a }
  subject { LogStash::Outputs::ElasticSearch.new(config) }
  
  let(:es_url) { "http://#{get_host_port}" }
  let(:index_url) {"#{es_url}/#{index}"}
  let(:http_client_options) { {} }
  let(:http_client) do
    Manticore::Client.new(http_client_options)
  end

  before do
    subject.register
  end
  
  shared_examples "an indexer" do |secure|
    it "ships events" do
      subject.multi_receive(events)

      http_client.post("#{es_url}/_refresh").call

      response = http_client.get("#{index_url}/_count?q=*")
      result = LogStash::Json.load(response.body)
      cur_count = result["count"]
      expect(cur_count).to eq(event_count)

      response = http_client.get("#{index_url}/_search?q=*&size=1000")
      result = LogStash::Json.load(response.body)
      result["hits"]["hits"].each do |doc|
        if ESHelper.es_version_satisfies?(">= 6")
          expect(doc["_type"]).to eq("doc")
        else
          expect(doc["_type"]).to eq(type)
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
        with(anything, anything, expected_manticore_opts).
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
    let(:type) { "doc" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    it_behaves_like("an indexer")
  end

  describe "a secured indexer", :elasticsearch_secure => true do
    let(:user) { "simpleuser" }
    let(:password) { "abc123" }
    let(:cacert) { "spec/fixtures/test_certs/test.crt" }
    let(:es_url) {"https://localhost:9200"}
    let(:config) do
      {
        "hosts" => ["localhost:9200"],
        "user" => user,
        "password" => password,
        "ssl" => true,
        "cacert" => "spec/fixtures/test_certs/test.crt",
        "index" => index
      }
    end
    let(:http_client_options) do
      {
        :auth => {
          :user => user,
          :password => password
        }, 
        :ssl => {
          :enabled => true,
          :ca_file => cacert
        }
      }
    end
    it_behaves_like("an indexer", true)
    
    describe "with a password requiring escaping" do
      let(:user) { "f@ncyuser" }
      let(:password) { "ab%12#" }
      
      include_examples("an indexer", true)
    end
    
    describe "with a user/password requiring escaping in the URL" do
      let(:config) do
        {
          "hosts" => ["https://#{CGI.escape(user)}:#{CGI.escape(password)}@localhost:9200"],
          "ssl" => true,
          "cacert" => "spec/fixtures/test_certs/test.crt",
          "index" => index
        }
      end
      
      include_examples("an indexer", true)
    end
  end
end
