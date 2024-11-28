require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "json"
require "socket"

describe "pool sniffer", :integration => true do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger, {}) }
  let(:es_host) { get_host_port.split(":").first }
  let(:es_port) { get_host_port.split(":").last }
  let(:es_ip) { IPSocket.getaddress(es_host) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://#{get_host_port}")] }
  let(:options) do
    {
      :resurrect_delay => 2, # Shorten the delay a bit to speed up tests
      :url_normalizer => proc {|u| u},
      :metric => ::LogStash::Instrument::NullMetric.new(:dummy).namespace(:alsodummy)
    }
  end

  subject { LogStash::Outputs::ElasticSearch::HttpClient::Pool.new(logger, adapter, initial_urls, options) }

  describe("Simple sniff parsing")  do
    before(:each) { subject.start }

    context "with single node" do
      it "should execute a sniff without error" do
        expect { subject.check_sniff }.not_to raise_error
      end

      it "should return single sniff URL" do
        uris = subject.check_sniff

        expect(uris.size).to eq(1)
      end
    end
  end

  describe("Complex sniff parsing") do
    before(:each) do
      response_double = double("_nodes/http", body: File.read("spec/fixtures/_nodes/7x.json"))
      allow(subject).to receive(:perform_request).and_return([nil, { version: "7.0" }, response_double])
      subject.start
    end

    context "with mixed master-only, data-only, and data + master nodes" do
      it "should execute a sniff without error" do
        expect { subject.check_sniff }.not_to raise_error
      end

      it "should return the correct sniff URLs" do
        # ie. with the master-only node, and with the node name correctly set.
        uris = subject.check_sniff

        expect(uris).to include(::LogStash::Util::SafeURI.new("//dev-masterdata:9201"), ::LogStash::Util::SafeURI.new("//dev-data:9202"))
      end
    end
  end
end
