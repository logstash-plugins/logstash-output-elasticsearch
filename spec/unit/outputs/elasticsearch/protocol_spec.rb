require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"

describe LogStash::Outputs::Elasticsearch::HttpClient do
  context "successful" do
    it "should map correctly" do
      bulk_response = {"took"=>74, "errors"=>false, "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
                                                                          "_type"=>"logs", "_id"=>"AUxTS2C55Jrgi-hC6rQF",
                                                                          "_version"=>1, "status"=>201}}]} 
      actual = LogStash::Outputs::Elasticsearch::HttpClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> false}
    end
  end

  context "contains failures" do
    it "should map correctly" do
      item_response = {"_index"=>"logstash-2014.11.17",
                       "_type"=>"logs", "_id"=>"AUxTQ_OI5Jrgi-hC6rQB", "status"=>400,
                       "error"=>"MapperParsingException[failed to parse]..."}
      bulk_response = {"took"=>71, "errors"=>true,
                       "items"=>[{"create"=>item_response}]}
      actual = LogStash::Outputs::Elasticsearch::HttpClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> true, "statuses"=> [400], "details" => [item_response]}
    end
  end

  describe "sniffing" do
    let(:base_options) { {:hosts => ["127.0.0.1"] }}
    let(:client) { LogStash::Outputs::Elasticsearch::HttpClient.new(base_options.merge(client_opts)) }
    let(:transport) { client.client.transport }

    before do
      allow(transport).to receive(:reload_connections!)
    end

    context "with sniffing enabled" do
      let(:client_opts) { {:sniffing => true, :sniffing_delay => 1 } }

      after do
        client.stop_sniffing!
      end

      it "should start the sniffer" do
        expect(client.sniffer_thread).to be_a(Thread)
      end

      it "should periodically sniff the client" do
        sleep 2
        expect(transport).to have_received(:reload_connections!)
      end
    end

    context "with sniffing disabled" do
      let(:client_opts) { {:sniffing => false} }

      it "should not start the sniffer" do
        expect(client.sniffer_thread).to be_nil
      end
    end

  end
end
