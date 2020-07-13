require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"
require "json"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  describe ".default_template_path" do
    context "elasticsearch 1.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(1)).to end_with("/templates/ecs-disabled/elasticsearch-2x.json")
      end
    end
    context "elasticsearch 2.x" do
      it "chooses the 2x template" do
        expect(described_class.default_template_path(2)).to end_with("/templates/ecs-disabled/elasticsearch-2x.json")
      end
    end
    context "elasticsearch 5.x" do
      it "chooses the 5x template" do
        expect(described_class.default_template_path(5)).to end_with("/templates/ecs-disabled/elasticsearch-5x.json")
      end
    end
  end
end
