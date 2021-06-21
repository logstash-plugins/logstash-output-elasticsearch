require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/template_manager"

describe LogStash::Outputs::ElasticSearch::TemplateManager do

  describe ".default_template_path" do
    context "elasticsearch 6.x" do
      it "chooses the 6x template" do
        expect(described_class.default_template_path(6)).to end_with("/templates/ecs-disabled/elasticsearch-6x.json")
      end
    end
    context "elasticsearch 7.x" do
      it "chooses the 7x template" do
        expect(described_class.default_template_path(7)).to end_with("/templates/ecs-disabled/elasticsearch-7x.json")
      end
    end
    context "elasticsearch 8.x" do
      it "chooses the 8x template" do
        expect(described_class.default_template_path(8)).to end_with("/templates/ecs-disabled/elasticsearch-8x.json")
      end
    end
  end

  context 'when ECS v1 is requested' do
    it 'resolves' do
      expect(described_class.default_template_path(7, :v1)).to end_with("/templates/ecs-v1/elasticsearch-7x.json")
    end
  end

  describe "index template with ilm settings" do
    let(:plugin_settings) { {"manage_template" => true, "template_overwrite" => true} }
    let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

    describe "in version 8+" do
      let(:file_path) { described_class.default_template_path(8) }
      let(:template) { described_class.read_template_file(file_path)}

      it "should update settings" do
        expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(8)
        described_class.add_ilm_settings_to_template(plugin, template)
        expect(template['template']['settings']['index.lifecycle.name']).not_to eq(nil)
        expect(template['template']['settings']['index.lifecycle.rollover_alias']).not_to eq(nil)
        expect(template.include?('settings')).to be_falsey
      end
    end

    describe "in version < 8" do
      let(:file_path) { described_class.default_template_path(7) }
      let(:template) { described_class.read_template_file(file_path)}

      it "should update settings" do
        expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(7)
        described_class.add_ilm_settings_to_template(plugin, template)
        expect(template['settings']['index.lifecycle.name']).not_to eq(nil)
        expect(template['settings']['index.lifecycle.rollover_alias']).not_to eq(nil)
        expect(template.include?('template')).to be_falsey
      end
    end
  end
end
