require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"
require "json"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  describe ".get_es_major_version" do
    let(:es_2x_version) { '{ "number" : "2.3.4", "build_hash" : "e455fd0c13dceca8dbbdbb1665d068ae55dabe3f", "build_timestamp" : "2016-06-30T11:24:31Z", "build_snapshot" : false, "lucene_version" : "5.5.0" }' }
    let(:es_5x_version) { '{ "number" : "5.0.0-alpha4", "build_hash" : "b0da471", "build_date" : "2016-06-22T12:33:48.164Z", "build_snapshot" : false, "lucene_version" : "6.1.0" }' }
    let(:client) { double("client") }
    context "elasticsearch 2.x" do
      before(:each) do
        allow(client).to receive(:get_version).and_return(JSON.parse(es_2x_version))
      end
      it "detects major version is 2" do
        expect(described_class.get_es_major_version(client)).to eq("2")
      end
    end
    context "elasticsearch 5.x" do
      before(:each) do
        allow(client).to receive(:get_version).and_return(JSON.parse(es_5x_version))
      end
      it "detects major version is 5" do
        expect(described_class.get_es_major_version(client)).to eq("5")
      end
    end
  end

  describe ".default_template_path" do
    context "elasticsearch 2.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path("2")).to match(/elasticsearch-template-es2x.json/)
      end
    end
    context "elasticsearch 5.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path("5")).to match(/elasticsearch-template-es5x.json/)
      end
    end
  end

end
