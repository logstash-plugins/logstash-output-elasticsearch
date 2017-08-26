require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"
require "json"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  describe ".get_es_major_version" do
    let(:client) { double("client") }

    before(:each) do
      allow(client).to receive(:connected_es_versions).and_return(["5.3.0"])
    end

    it "picks the largest major version" do
      expect(described_class.get_es_major_version(client)).to eq(5)
    end
    context "if there are nodes with multiple major versions" do
      before(:each) do
        allow(client).to receive(:connected_es_versions).and_return(["5.3.0", "6.0.0"])
      end
      it "picks the largest major version" do
        expect(described_class.get_es_major_version(client)).to eq(6)
      end
    end
  end

  describe ".default_template_path" do
    context "elasticsearch 1.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(1)).to match(/elasticsearch-template-es2x.json/)
      end
    end
    context "elasticsearch 2.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(2)).to match(/elasticsearch-template-es2x.json/)
      end
    end
    context "elasticsearch 5.x" do
      it "chooses the 5x template" do
        expect(described_class.default_template_path(5)).to match(/elasticsearch-template-es5x.json/)
      end
    end
  end
end
