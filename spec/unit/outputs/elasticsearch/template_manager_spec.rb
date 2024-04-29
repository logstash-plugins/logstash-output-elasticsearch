require_relative "../../../../spec/spec_helper"
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

  context 'when ECS v8 is requested' do
    it 'resolves' do
      expect(described_class.default_template_path(7, :v8)).to end_with("/templates/ecs-v8/elasticsearch-7x.json")
    end
  end

  context "index template with ilm settings" do
    let(:plugin_settings) { {"manage_template" => true, "template_overwrite" => true} }
    let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

    describe "with custom template" do

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

    context "resolve template setting" do
      let(:plugin_settings) { super().merge({"template_api" => template_api}) }

      describe "with composable template API" do
        let(:template_api) { "composable" }

        it 'resolves composable index template API compatible setting' do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(8) # required to log
          template = {}
          described_class.resolve_template_settings(plugin, template)
          expect(template["template"]["settings"]).not_to eq(nil)
        end
      end

      describe "with legacy template API" do
        let(:template_api) { "legacy" }

        it 'resolves legacy index template API compatible setting' do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(7) # required to log
          template = {}
          described_class.resolve_template_settings(plugin, template)
          expect(template["settings"]).not_to eq(nil)
        end
      end

      describe "with `template_api => 'auto'`" do
        let(:template_api) { "auto" }

        describe "with ES < 8 versions" do

          it 'resolves legacy index template API compatible setting' do
            expect(plugin).to receive(:serverless?).and_return(false)
            expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(7)
            template = {}
            described_class.resolve_template_settings(plugin, template)
            expect(template["settings"]).not_to eq(nil)
          end
        end

        describe "with ES >= 8 versions" do
          it 'resolves composable index template API compatible setting' do
            expect(plugin).to receive(:serverless?).and_return(false)
            expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(8)
            template = {}
            described_class.resolve_template_settings(plugin, template)
            expect(template["template"]["settings"]).not_to eq(nil)
          end
        end
      end
    end
  end

  describe "template endpoint" do
    describe "template_api => 'auto'" do
      let(:plugin_settings) { {"manage_template" => true, "template_api" => 'auto'} }
      let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

      describe "in version 8+" do
        it "should use index template API" do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(8)
          endpoint = described_class.template_endpoint(plugin)
          expect(endpoint).to be_equal(LogStash::Outputs::ElasticSearch::TemplateManager::INDEX_TEMPLATE_ENDPOINT)
        end
      end

      describe "in version < 8" do
        it "should use legacy template API" do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).at_least(:once).and_return(7)
          endpoint = described_class.template_endpoint(plugin)
          expect(endpoint).to be_equal(LogStash::Outputs::ElasticSearch::TemplateManager::LEGACY_TEMPLATE_ENDPOINT)
        end
      end
    end

    describe "template_api => 'legacy'" do
      let(:plugin_settings) { {"manage_template" => true, "template_api" => 'legacy'} }
      let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

      describe "in version 8+" do
        it "should use legacy template API" do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).never
          endpoint = described_class.template_endpoint(plugin)
          expect(endpoint).to be_equal(LogStash::Outputs::ElasticSearch::TemplateManager::LEGACY_TEMPLATE_ENDPOINT)
        end
      end
    end

    describe "template_api => 'composable'" do
      let(:plugin_settings) { {"manage_template" => true, "template_api" => 'composable'} }
      let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

      describe "in version 8+" do
        it "should use legacy template API" do
          expect(plugin).to receive(:serverless?).and_return(false)
          expect(plugin).to receive(:maximum_seen_major_version).never
          endpoint = described_class.template_endpoint(plugin)
          expect(endpoint).to be_equal(LogStash::Outputs::ElasticSearch::TemplateManager::INDEX_TEMPLATE_ENDPOINT)
        end
      end
    end

    describe "in serverless" do
      [:auto, :composable, :legacy].each do |api|
        let(:plugin_settings) { {"manage_template" => true, "template_api" => api.to_s} }
        let(:plugin) { LogStash::Outputs::ElasticSearch.new(plugin_settings) }

        it "use index template API when template_api set to #{api}" do
          expect(plugin).to receive(:serverless?).and_return(true)
          endpoint = described_class.template_endpoint(plugin)
          expect(endpoint).to be_equal(LogStash::Outputs::ElasticSearch::TemplateManager::INDEX_TEMPLATE_ENDPOINT)
        end
      end

    end
  end
end
