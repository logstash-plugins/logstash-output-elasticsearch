require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"
require "stringio"

RSpec::Matchers.define :a_valid_gzip_encoded_string do
  match { |data|
    expect { Zlib::GzipReader.new(StringIO.new(data)).read }.not_to raise_error
  }
end

if ESHelper.es_version_satisfies?(">= 5")
  describe "indexing with http_compression turned on", :integration => true do
    let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:events) { event_count.times.map { event }.to_a }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index,
        "http_compression" => true
      }
    }
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

    shared_examples "an indexer" do
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
            expect(doc["_type"]).to eq(doc_type)
          else
            expect(doc["_type"]).to eq(type)
          end
          expect(doc["_index"]).to eq(index)
        end
      end
    end

    it "sets the correct content-encoding header and body is compressed" do
      # Allow xpack endpoint to be checked\
      allow(subject.client.pool.adapter.client).to receive(:send).at_least(:once).with(anything, /_template/, anything).and_call_original
      allow(subject.client.pool.adapter.client).to receive(:send).with(anything, /_xpack/, anything).and_call_original
      allow(subject.client.pool.adapter.client).to receive(:send).with(anything, /logstash/, anything).and_call_original
      allow(subject.client.pool.adapter.client).to receive(:send).with(anything, /_ilm/, anything).and_call_original
      expect(subject.client.pool.adapter.client).to receive(:send).
        with(anything, anything, {:headers=>{"Content-Encoding"=>"gzip", "Content-Type"=>"application/json"}, :body => a_valid_gzip_encoded_string}).
        and_call_original
      subject.multi_receive(events)
    end

    it_behaves_like("an indexer")
  end
end
