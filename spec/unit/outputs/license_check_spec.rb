require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "logstash/outputs/elasticsearch/license_checker"

describe LogStash::Outputs::ElasticSearch::LicenseChecker do

  # Note that the actual license checking logic is spec'ed in pool_spec.rb

  context "LicenseChecker API required by Pool class" do
    subject { described_class }

    it "defines the appropriate_license? methods" do
      expect(subject.instance_methods).to include(:appropriate_license?)
    end
  end

  context "Pool class API required by the LicenseChecker" do
    subject { LogStash::Outputs::ElasticSearch::HttpClient::Pool }

    it "contains the get_license method" do
      expect(LogStash::Outputs::ElasticSearch::HttpClient::Pool.instance_methods).to include(:get_license)
    end
  end

  context "appropriate license" do
    let(:logger) { double("logger") }
    let(:url) { LogStash::Util::SafeURI.new("https://cloud.elastic.co") }
    let(:pool) { double("pool") }
    subject { described_class.new(logger) }

    it "is true when connect to serverless" do
      allow(pool).to receive(:serverless?).and_return(true)
      expect(subject.appropriate_license?(pool, url)).to eq true
    end

    it "is true when license status is active" do
      allow(pool).to receive(:serverless?).and_return(false)
      allow(pool).to receive(:get_license).with(url).and_return(LogStash::Json.load File.read("spec/fixtures/license_check/active.json"))
      expect(subject.appropriate_license?(pool, url)).to eq true
    end

    it "is true when license status is inactive" do
      allow(logger).to receive(:warn).with(instance_of(String), anything)
      allow(pool).to receive(:serverless?).and_return(false)
      allow(pool).to receive(:get_license).with(url).and_return(LogStash::Json.load File.read("spec/fixtures/license_check/inactive.json"))
      expect(subject.appropriate_license?(pool, url)).to eq true
    end

    it "is false when no license return" do
      allow(logger).to receive(:error).with(instance_of(String), anything)
      allow(pool).to receive(:serverless?).and_return(false)
      allow(pool).to receive(:get_license).with(url).and_return(LogStash::Json.load('{}'))
      expect(subject.appropriate_license?(pool, url)).to eq false
    end
  end
end

