require_relative "../../../spec/es_spec_helper"
require 'stud/temporary'
require "logstash/outputs/elasticsearch"

describe "Proxy option" do
  let(:settings) {
    {
      "hosts" => "node01",
      "proxy" => proxy
    }
  }
  subject {
    LogStash::Outputs::ElasticSearch.new(settings)
  }

  before do
    allow(::Manticore::Client).to receive(:new).with(any_args)
  end

  describe "valid configs" do
    before do
      subject.register
    end

    context "when specified as a string" do
      let(:proxy) { "http://127.0.0.1:1234" }

      it "should set the proxy to the exact value" do
        expect(::Manticore::Client).to have_received(:new) do |options|
          expect(options[:proxy]).to eql(proxy)
        end
      end
    end

    context "when specified as a hash" do
      let(:proxy) { {"hosts" => "127.0.0.1", "protocol" => "http"} }

      it "should pass through the proxy values as symbols" do
        expected = {:hosts => proxy["hosts"], :protocol => proxy["protocol"]}
        expect(::Manticore::Client).to have_received(:new) do |options|
          expect(options[:proxy]).to eql(expected)
        end
      end
    end

    context "when not specified" do
      let(:proxy) { nil }
      
      it "should not send the proxy option to manticore" do
        expect(::Manticore::Client).to have_received(:new) do |options|
          expect(options).not_to include(:proxy)
        end
      end
    end
  end

  describe "invalid configs" do
    let(:proxy) { ["bad", "stuff"] }

    it "should have raised an exception" do
      expect {
        subject.register
      }.to raise_error(LogStash::ConfigurationError)
    end
  end

end
