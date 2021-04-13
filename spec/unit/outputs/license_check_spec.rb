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
end

