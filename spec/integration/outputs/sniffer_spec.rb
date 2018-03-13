require "logstash/devutils/rspec/spec_helper"
require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "json"

describe "pool sniffer", :integration => true do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger) }
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

      it "should return the correct sniff URL" do
        if ESHelper.es_version_satisfies?(">= 2")
          # We do a more thorough check on these versions because we can more reliably guess the ip
          uris = subject.check_sniff

          expect(uris).to include(::LogStash::Util::SafeURI.new("//#{get_host_port}"))
        else
          # ES 1.x returned the public hostname by default. This is hard to approximate
          # so for ES1.x we don't check the *exact* hostname
          skip
        end
      end
    end
  end

  if ESHelper.es_version_satisfies?("<= 2")
    describe("Complex sniff parsing ES 2x/1x") do
      before(:each) do
        response_double = double("_nodes/http", body: File.read("spec/fixtures/_nodes/2x_1x.json"))
        allow(subject).to receive(:perform_request).and_return([nil, { version: "2.0" }, response_double])
        subject.start
      end

      context "with multiple nodes but single http-enabled data node" do
        it "should execute a sniff without error" do
          expect { subject.check_sniff }.not_to raise_error
        end

        it "should return one sniff URL" do
          uris = subject.check_sniff

          expect(uris.size).to eq(1)
        end

        it "should return the correct sniff URL" do
          if ESHelper.es_version_satisfies?(">= 2")
            # We do a more thorough check on these versions because we can more reliably guess the ip
            uris = subject.check_sniff

            expect(uris).to include(::LogStash::Util::SafeURI.new("http://localhost:9201"))
          else
            # ES 1.x returned the public hostname by default. This is hard to approximate
            # so for ES1.x we don't check the *exact* hostname
            skip
          end
        end
      end
    end
  end

  if ESHelper.es_version_satisfies?(">= 5")
    describe("Complex sniff parsing ES 6x/5x") do
      before(:each) do
        response_double = double("_nodes/http", body: File.read("spec/fixtures/_nodes/5x_and_above.json"))
        allow(subject).to receive(:perform_request).and_return([nil, { version: "5.0" }, response_double])
        subject.start
      end

      context "with mixed master-only, data-only, and data + master nodes" do
        it "should execute a sniff without error" do
          expect { subject.check_sniff }.not_to raise_error
        end

        it "should return the correct sniff URLs" do
          # ie. without the master-only node
          uris = subject.check_sniff

          expect(uris).to include(::LogStash::Util::SafeURI.new("http://localhost:9201"), ::LogStash::Util::SafeURI.new("http://localhost:9202"), ::LogStash::Util::SafeURI.new("http://localhost:9203"))
        end
      end
    end
  end
end
