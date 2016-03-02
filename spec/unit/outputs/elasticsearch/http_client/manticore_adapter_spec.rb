require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"

describe LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter do
  let(:logger) { Cabin::Channel.get }
  let(:options) { {} }

  subject { described_class.new(logger, options) }

  it "should raise an exception if requests are issued after close" do
    subject.close
    expect { subject.perform_request("http://localhost:9200", :get, '/') }.to raise_error(::Manticore::ClientStoppedException)
  end

  it "should implement host unreachable exceptions" do
    expect(subject.host_unreachable_exceptions).to be_a(Array)
  end

  describe "integration specs", :integration => true do
    it "should perform correct tests without error" do
      resp = subject.perform_request("http://localhost:9200", :get, "/")
      expect(resp.code).to eql(200)
    end
  end
end
