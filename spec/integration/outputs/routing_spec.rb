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
      index_url = "http://#{get_host_port()}/#{index}"

      client = Manticore::Client.new
      client.post("#{index_url}/_refresh").call

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""

        response = client.get("#{index_url}/_count?q=*&routing=#{routing}").call
        result = LogStash::Json.load(response.body)
        cur_count = result["count"]
        expect(cur_count).to eq(event_count)
      end
    end
end

# describe "(http protocol) index events with static routing", :integration => true do
#   it_behaves_like 'a routing indexer' do
#     let(:routing) { "test" }
#     let(:config) {
#       {
#         "hosts" => get_host_port,
#         "index" => index,
#         "routing" => routing
#       }
#     }
#   end
# end
# 
# describe "(http_protocol) index events with fieldref in routing value", :integration => true do
#   it_behaves_like 'a routing indexer' do
#     let(:routing) { "test" }
#     let(:config) {
#       {
#         "hosts" => get_host_port,
#         "index" => index,
#         "routing" => "%{message}"
#       }
#     }
#   end
# end
