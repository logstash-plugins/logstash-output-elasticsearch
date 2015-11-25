require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"

describe LogStash::Outputs::ElasticSearch::HttpClient do
  describe "sniffing" do
    let(:base_options) { {:hosts => ["127.0.0.1"], :logger => Cabin::Channel.get }}
    let(:client) { LogStash::Outputs::ElasticSearch::HttpClient.new(base_options.merge(client_opts)) }
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
        expect(transport).to have_received(:reload_connections!).at_least(:once)
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
