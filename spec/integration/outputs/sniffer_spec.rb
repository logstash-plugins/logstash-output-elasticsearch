require "logstash/devutils/rspec/spec_helper"
require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "json"

describe "pool sniffer", :integration => true do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://#{get_host_port}")] }
  let(:options) { {:resurrect_delay => 2, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests

  subject { LogStash::Outputs::ElasticSearch::HttpClient::Pool.new(logger, adapter, initial_urls, options) }

  describe("Simple sniff parsing")  do
    before(:each) { subject.start }

    context "with only one URL in the list" do
      it "should execute a sniff without error" do
        expect { subject.check_sniff }.not_to raise_error
      end

      it "should return the correct sniff URL list" do
        uris = subject.check_sniff

        # ES 1.x returned the public hostname by default. This is hard to approximate
        # so for ES1.x we don't check the *exact* hostname
        expect(uris.size).to eq(1)
      end
    end

    context "with multiple URLs in the list no roles" do
      let(:initial_urls) { [ ::LogStash::Util::SafeURI.new("http://localhost:9200"), ::LogStash::Util::SafeURI.new("http://localhost:9201"), ::LogStash::Util::SafeURI.new("http://localhost:9202") ] }

      it "should execute a sniff without error" do
        expect { subject.check_sniff }.not_to raise_error
      end

      it "should return the correct sniff URL list" do
        uris = subject.check_sniff

        # Without roles we should expect to see all nodes returned
        expect(uris.size).to eq(3)
      end
    end
  end

  if ESHelper.es_version_satisfies?(">= 2")
    # We do a more thorough check on these versions because we can more reliably guess the ip
    describe("Complex sniff parsing ES 6x/5x/2x") do
      before(:each) { subject.start }

      context "with only one URL in the list" do
        it "should execute a sniff without error" do
          expect { subject.check_sniff }.not_to raise_error
        end

        it "should return the correct sniff URL list" do
          uris = subject.check_sniff

          expect(uris).to include(::LogStash::Util::SafeURI.new("//#{get_host_port}"))
        end
      end

      context "with multiple URLs in the list but single data node" do
        before :each do
          allow(adapter).to receive(:perform_request).with(anything, :get, subject.sniffing_path, {}, nil).to_return(nil, nil, {body: fixture('_nodes.json')})
        end

        it "should execute a sniff without error" do
          expect { subject.check_sniff }.not_to raise_error
        end

        it "should return the correct sniff URL list" do
          uris = subject.check_sniff

          # With roles there should only be one of three nodes returned
          expect(uris.size).to eq(1)
          expect(uris).to include("http://localhost:9201")
        end
      end
    end
  end
end
