require_relative "../../../spec/es_spec_helper"

shared_examples "a routing indexer" do
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:routing) { "not_implemented" }
    let(:config) { "not_implemented" }
    subject { LogStash::Outputs::ElasticSearch.new(config) }

    before do
      subject.register
      event_count.times do
        subject.multi_receive([LogStash::Event.new("message" => "test", "type" => type)])
      end
    end


    it "ships events" do
      send_refresh

      # Wait until all events are available.
      Stud::try(10.times) do
        response = send_json_request(:get, "#{index}/_count", :query => {routing: routing})
        
        cur_count = response["count"]
        expect(cur_count).to eq(event_count)
      end
    end
end

describe "(http protocol) index events with static routing", :integration => true do
  it_behaves_like 'a routing indexer' do
    let(:routing) { "test" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index,
        "routing" => routing
      }
    }
  end
end

describe "(http_protocol) index events with fieldref in routing value", :integration => true do
  it_behaves_like 'a routing indexer' do
    let(:routing) { "test" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index,
        "routing" => "%{message}"
      }
    }
  end
end
