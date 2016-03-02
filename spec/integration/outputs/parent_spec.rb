require_relative "../../../spec/es_spec_helper"

shared_examples "a parent indexer" do
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:flush_size) { rand(200) + 1 }
    let(:parent) { "not_implemented" }
    let(:config) { "not_implemented" }
    subject { LogStash::Outputs::ElasticSearch.new(config) }

    before do
      # Add mapping and a parent document
      index_url = "http://#{get_host_port()}/#{index}"
      ftw = FTW::Agent.new
      mapping = { "mappings" => { "#{type}" => { "_parent" => { "type" => "#{type}_parent" } } } }
      ftw.put!("#{index_url}", :body => mapping.to_json)
      pdoc = { "foo" => "bar" }
      ftw.put!("#{index_url}/#{type}_parent/test", :body => pdoc.to_json)
      
      subject.register
      subject.multi_receive(event_count.times.map { LogStash::Event.new("link_to" => "test", "message" => "Hello World!", "type" => type) })
    end


    it "ships events" do
      index_url = "http://#{get_host_port()}/#{index}"

      ftw = FTW::Agent.new
      ftw.post!("#{index_url}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        query = { "query" => { "has_parent" => { "type" => "#{type}_parent", "query" => { "match" => { "foo" => "bar" } } } } }
        data = ""
        response = ftw.post!("#{index_url}/_count?q=*", :body => query.to_json)
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        cur_count = result["count"]
        insist { cur_count } == event_count
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
        "flush_size" => flush_size,
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
        "flush_size" => flush_size,
        "parent" => "%{link_to}"
      }
    }
  end
end

