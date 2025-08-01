require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"
require "stringio"

RSpec::Matchers.define :a_valid_gzip_encoded_string do
  match { |data|
    expect { Zlib::GzipReader.new(StringIO.new(data)).read }.not_to raise_error
  }
end

[ {"http_compression" => true}, {"compression_level" => 1} ].each do |compression_config|
  describe "indexing with http_compression turned on", :integration => true do
    let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
    let(:event_with_invalid_utf_8_bytes) { LogStash::Event.new("message" => "Message from spacecraft which contains \xAC invalid \xD7 byte sequences.", "type" => type) }

    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { ESHelper.es_version_satisfies?("< 7") ? "doc" : "_doc" }
    let(:event_count) { 10000 + rand(500) }
    # mix the events with valid and invalid UTF-8 payloads
    let(:events) { event_count.times.map { |i| i%3 == 0 ? event : event_with_invalid_utf_8_bytes }.to_a }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
    subject { LogStash::Outputs::ElasticSearch.new(config.merge(compression_config)) }

    let(:es_url) { "http://#{get_host_port}" }
    let(:index_url) {"#{es_url}/#{index}"}
    let(:http_client_options) { {} }
    let(:http_client) do
      Manticore::Client.new(http_client_options)
    end
    let(:expected_headers) {
      {
        "Content-Encoding" => "gzip",
        "Content-Type" => "application/json",
        'x-elastic-product-origin' => 'logstash-output-elasticsearch',
        'X-Elastic-Event-Count' => anything,
        'X-Elastic-Uncompressed-Request-Length' => anything,
      }
    }

    before do
      subject.register
      subject.multi_receive([])
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
          if ESHelper.es_version_satisfies?("< 8")
            expect(doc["_type"]).to eq(type)
          else
            expect(doc).not_to include("_type")
          end
          expect(doc["_index"]).to eq(index)
        end
      end
    end

    it "sets the correct content-encoding header and body is compressed" do
      expect(subject.client.pool.adapter.client).to receive(:send).
        with(anything, anything, {:headers=> expected_headers, :body => a_valid_gzip_encoded_string}).
        and_call_original
      subject.multi_receive(events)
    end

    it_behaves_like("an indexer")
  end
end