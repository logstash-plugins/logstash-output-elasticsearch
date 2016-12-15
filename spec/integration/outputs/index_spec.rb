require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"

shared_examples "an indexer" do
    let(:event) { LogStash::Event.new("message" => "Hello World!", "type" => type) }
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:config) { "not implemented" }
    let(:events) { event_count.times.map { event }.to_a }
    subject { LogStash::Outputs::ElasticSearch.new(config) }

    before do
      subject.register
    end

    it "ships events" do
      subject.multi_receive(events)
      index_url = "http://#{get_host_port}/#{index}"

      ftw = FTW::Agent.new
      ftw.post!("#{index_url}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("#{index_url}/_count?q=*")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        cur_count = result["count"]
        insist { cur_count } == event_count
      end

      response = ftw.get!("#{index_url}/_search?q=*&size=1000")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      result["hits"]["hits"].each do |doc|
        insist { doc["_type"] } == type
        insist { doc["_index"] } == index
      end
    end
end

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
    puts "RAW CURLTEST #{`curl http://localhost:9200`}"
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


describe "an indexer with custom index_type", :integration => true do
  it_behaves_like "an indexer" do
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
  end
end

describe "an indexer with no type value set (default to logs)", :integration => true do
  it_behaves_like "an indexer" do
    let(:type) { "logs" }
    let(:config) {
      {
        "hosts" => get_host_port,
        "index" => index
      }
    }
  end
end
