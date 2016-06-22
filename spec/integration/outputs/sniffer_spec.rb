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
  
  before do
    subject.start
  end
  
  shared_examples("sniff parsing") do |check_exact|
    it "should execute a sniff without error" do
      expect { subject.check_sniff }.not_to raise_error
    end

    it "should return the correct sniff URL list" do
      uris = subject.check_sniff
      
      # ES 1.x returned the public hostname by default. This is hard to approximate
      # so for ES1.x we don't check the *exact* hostname
      if check_exact
        expect(uris).to include(::LogStash::Util::SafeURI.new("//#{get_host_port}"))
      else
        expect(uris.size).to eq(1)
      end
    end
  end
  
  describe("Simple sniff parsing")  do
    include_examples("sniff parsing", false)
  end
  
  # We do a more thorough check on these versions because we can more reliably guess the ip
  describe("Complex sniff parsing ES 5x/2x", :version_greater_than_equal_to_2x => true) do
    include_examples("sniff parsing", true)
  end
end
