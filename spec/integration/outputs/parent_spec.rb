require_relative "../../../spec/es_spec_helper"

shared_examples "a parent indexer" do
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:parent) { "not_implemented" }
    let(:config) { "not_implemented" }
    subject { LogStash::Outputs::ElasticSearch.new(config) }

    before do
      # Add mapping and a parent document
      mapping = { "mappings" => { "#{type}" => { "_parent" => { "type" => "#{type}_parent" } } } }
      send_request(:put, "#{index}", :body => mapping.to_json)
      send_request(:put, "#{index}/#{type}_parent/test", :body => {"foo" => "bar"})

      subject.register
      subject.multi_receive(event_count.times.map { LogStash::Event.new("link_to" => "test", "message" => "Hello World!", "type" => type) })
    end


    it "ships events" do
      send_request(:post,"#{index}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        query = { "query" => { "has_parent" => { "type" => "#{type}_parent", "query" => { "match" => { "foo" => "bar" } } } } }
        data = ""
        result = send_json_request(:post, "#{index}/_count", :body => query.to_json)
        cur_count = result["count"]
        expect(cur_count).to eq(event_count)
      end
    end
end

describe "(http protocol) index events with static parent", :integration => true do
  it_behaves_like 'a parent indexer' do
    let(:parent) { "test" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index,
        "parent" => parent
      }
    }
  end
end

describe "(http_protocol) index events with fieldref in parent value", :integration => true do
  it_behaves_like 'a parent indexer' do
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index,
        "parent" => "%{link_to}"
      }
    }
  end
end
