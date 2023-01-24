require_relative '../../../../spec/spec_helper'
require "logstash/outputs/elasticsearch/data_stream_support"

describe LogStash::Outputs::ElasticSearch::DataStreamSupport do

  subject { LogStash::Outputs::ElasticSearch.new(options) }

  let(:options) { { 'hosts' => [ 'localhost:12345' ] } }
  let(:es_version) { '7.10.1' }

  # All data-streams features require that the plugin be run in a non-disabled ECS compatibility mode.
  # We run the plugin in ECS by default, and add test scenarios specifically for it being disabled.
  let(:ecs_compatibility) { :v1 }
  before(:each) do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch).to receive(:ecs_compatibility).and_return(ecs_compatibility)
  end

  let(:do_register) { false }
  let(:stub_plugin_register!) do
    allow(subject).to receive(:last_es_version).and_return(es_version)

    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:start)

    # stub-out unrelated (finish_register) setup:
    allow(subject).to receive(:discover_cluster_uuid)
    allow(subject).to receive(:install_template)
    allow(subject).to receive(:ilm_in_use?).and_return nil

    # emulate 'successful' ES connection on the same thread
    allow(subject).to receive(:after_successful_connection) { |&block| block.call }
    allow(subject).to receive(:stop_after_successful_connection_thread)

    subject.register

    allow(subject.client).to receive(:maximum_seen_major_version).and_return(Integer(es_version.split('.').first))

    # allow( subject.logger ).to receive(:info) do |msg|
    #   expect(msg).to include "New Elasticsearch output"
    # end
  end

  before(:each) do
    stub_plugin_register! if do_register
  end

  after(:each) do
    subject.close if do_register
  end

  context "default configuration" do

    let(:options) { {} }

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does not use data-streams on LS 7.x" do
      change_constant :LOGSTASH_VERSION, '7.10.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "warns when configuration is data-stream compliant (LS 7.x)" do
      expect( subject.logger ).to receive(:warn).with(a_string_including "Configuration is data stream compliant but due backwards compatibility Logstash 7.x")
      change_constant :LOGSTASH_VERSION, '7.11.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "defaults to using data-streams on LS 8.0" do
      change_constant :LOGSTASH_VERSION, '8.0.0' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    context 'ecs_compatibility disabled' do
      let(:ecs_compatibility) { :disabled }

      {
        '7.x (pre-DS)' => '7.9.0',
        '7.x (with DS)' => '7.11.0',
        '8.0' => '8.0.0',
        '8.x' => '8.1.2',
      }.each do |ls_version_desc, ls_version|
        context "on LS #{ls_version_desc}" do
          around(:each) { |example| change_constant(:LOGSTASH_VERSION, ls_version, &example) }
          it "does not use data-streams" do
            expect( subject.logger ).to receive(:info).with(a_string_including "ecs_compatibility is not enabled")
            expect( subject.logger ).to receive(:info).with(a_string_including "Data streams auto configuration (`data_stream => auto` or unset) resolved to `false`")
            expect( subject.data_stream_config? ).to be false
          end
        end
      end
    end

    context 'non-compatible ES' do

      let(:es_version) { '7.8.0' }

      it "does not print an error (from after_successful_connection thread)" do
        change_constant :LOGSTASH_VERSION, '7.8.1' do
          expect( subject.logger ).to_not receive(:error)
          expect( subject ).to receive(:finish_register).once.and_call_original
          stub_plugin_register!
        end
      end

    end

  end

  context "ds-compatible configuration" do

    let(:options) do
      {
          'hosts' => [ 'http://127.0.0.1:12345' ],
          'http_compression' => 'true', 'bulk_path' => '_bulk', 'timeout' => '30',
          'user' => 'elastic', 'password' => 'ForSearch!', 'ssl' => 'false'
      }
    end

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does not use data-streams on LS 7.x" do
      expect( subject.logger ).to receive(:warn).with(a_string_including "Logstash 7.x will not assume writing to a data-stream")
      change_constant :LOGSTASH_VERSION, '7.10.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "defaults to using data-streams on LS 8.0" do
      change_constant :LOGSTASH_VERSION, '8.0.1' do
        expect( subject.data_stream_config? ).to be true
      end
      change_constant :LOGSTASH_VERSION, '8.1.0' do
        expect( subject.send(:check_data_stream_config!) ).to be true
      end
    end

    context 'old ES' do

      let(:es_version) { '7.8.1' }

      it "prints an error (from after_successful_connection thread) on LS 8.0" do
        change_constant :LOGSTASH_VERSION, '8.0.0' do
          expect( subject.logger ).to receive(:error).with(/Elasticsearch version does not support data streams/,
                                                           {:es_version=>"7.8.1"})
          stub_plugin_register!
        end
      end

    end

  end

  context 'ds value-dependent configuration' do
    # Valid settings values
    let(:options) { super().merge(
      'action' => 'create',
      'routing' => 'any',
      'pipeline' => 'any',
      'manage_template' => "false",
      'data_stream' => 'true')
    }

    context 'with valid values' do
      let(:options) { super().merge(
        'data_stream_type' => 'logs',
        'data_stream_dataset' => 'any',
        'data_stream_namespace' => 'any',
        'data_stream_sync_fields' => true,
        'data_stream_auto_routing' => true)
      }

      it 'should enable data-streams by default' do
        expect ( subject.data_stream_config? ).to be true
      end
    end

    context 'with invalid values' do
      let(:options) { super().merge(
        'action' => 'index',
        'manage_template' => 'true')
      }

      it 'should raise a configuration error' do
        expect { subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, 'Invalid data stream configuration: ["action", "manage_template"]')
      end
    end
  end

  context "default (non data-stream) configuration (on 7.x)" do

    let(:options) do
      { 'data_stream_dataset' => 'test', 'data_stream_auto_routing' => 'false', 'user' => 'elastic' }
    end

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does not default to data-streams" do
      expect( subject.logger ).to receive(:error) do |msg|
        expect(msg).to include "Ambiguous configuration; data stream settings must not be present when data streams are disabled"
      end
      change_constant :LOGSTASH_VERSION, '7.10.2' do
        expect { subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, /Ambiguous configuration/i)
      end
    end

    context 'explicit data_stream => false' do

      let(:options) { super().merge('data_stream' => 'false') }

      it "raises a configuration error (due ds specific settings)" do
        expect( subject.logger ).to receive(:error).with(/Ambiguous configuration; data stream settings must not be present when data streams are disabled/,
                                                          {"data_stream_auto_routing"=>"false", "data_stream_dataset"=>"test"})
        change_constant :LOGSTASH_VERSION, '7.10.2' do
          expect { subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, /Ambiguous configuration/i)
        end
      end

    end

  end

  context "(explicit) ds disabled configuration" do

    let(:options) { super().merge('data_stream' => false.to_s) }

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does not use data-streams on LS 7.x" do
      change_constant :LOGSTASH_VERSION, '7.10.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "does not use data-streams on LS 8.0" do
      change_constant :LOGSTASH_VERSION, '8.0.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "does not print a warning" do
      expect( subject.logger ).to_not receive(:warn)
      change_constant :LOGSTASH_VERSION, '7.10.2' do
        expect( subject.data_stream_config? ).to be false
      end
    end

  end

  context "(explicit) ds enabled configuration" do

    let(:options) { super().merge('data_stream' => true.to_s) }

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does use data-streams on LS 7.x" do
      change_constant :LOGSTASH_VERSION, '7.9.1' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    it "does use data-streams on LS 8.x" do
      change_constant :LOGSTASH_VERSION, '8.1.0' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    context 'with ecs_compatibility disabled' do
      let(:ecs_compatibility) { :disabled }

      context 'when running on LS 7.x' do
        around(:each) { |example| change_constant(:LOGSTASH_VERSION, '7.15.1', &example) }

        it "emits a deprecation warning and uses data streams anway" do
          expect( subject.deprecation_logger ).to receive(:deprecated).with(a_string_including "`data_stream => true` will require the plugin to be run in ECS compatibility mode")
          expect( subject.data_stream_config? ).to be true
        end
      end

      context 'when running on LS 8.x' do
        around(:each) { |example| change_constant(:LOGSTASH_VERSION, '8.0.0', &example) }

        it "errors helpfully" do
          expect{ subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, a_string_including("Invalid data stream configuration: `ecs_compatibility => disabled`"))
        end
      end

    end

    context 'non-compatible ES' do

      let(:es_version) { '6.8.11' }

      it "prints an error (from after_successful_connection thread) on LS 7.x" do
        change_constant :LOGSTASH_VERSION, '7.12.0' do
          expect( subject.logger ).to receive(:error).with(/Elasticsearch version does not support data streams/,
                                                           {:es_version=>"6.8.11"})
          stub_plugin_register!
        end
      end

      it "prints an error (from after_successful_connection thread) on LS 8.0" do
        change_constant :LOGSTASH_VERSION, '8.0.5' do
          expect( subject.logger ).to receive(:error).with(/Elasticsearch version does not support data streams/,
                                                           {:es_version=>"6.8.11"})
          stub_plugin_register!
        end
      end

    end

  end

  describe "auto routing" do

    let(:options) { super().merge('data_stream' => 'true') }
    let(:do_register) { true }

    let(:event) do
      event = LogStash::Event.new
      event.set '[host][hostname]', 'orangutan'
      event
    end

    context 'with data_stream.* event data' do

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][type]', 'metrics'
          event.set '[data_stream][dataset]', 'src1'
          event.set '[data_stream][namespace]', 'test'
        end
      end

      it 'uses event specified target' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[0] ).to eql 'create'
        expect( tuple[1] ).to include :_index => 'metrics-src1-test'
      end

    end

    context 'with routing turned off' do

      let(:options) { super().merge('data_stream_auto_routing' => 'false') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][type]', 'metrics'
          event.set '[data_stream][dataset]', 'src1'
          event.set '[data_stream][namespace]', 'test'
        end
      end

      it 'uses event specified target' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[0] ).to eql 'create'
        expect( tuple[1] ).to include :_index => 'logs-generic-default'
      end

    end

    context 'with partial data_stream.* data' do

      let(:options) { super().merge('data_stream_dataset' => 'data') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][type]', 'metrics'
          event.set '[data_stream][dataset]', 'src1'
        end
      end

      it 'uses event specified target' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[0] ).to eql 'create'
        expect( tuple[1] ).to include :_index => 'metrics-src1-default'
      end

    end

    context 'with no data_stream.* fields' do

      let(:options) { super().merge('data_stream_dataset' => 'stats', 'data_stream_type' => 'metrics') }

      it 'uses configuration target' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[0] ).to eql 'create'
        expect( tuple[1] ).to include :_index => 'metrics-stats-default'
      end

    end

    context 'with default configuration' do

      it 'uses default target' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[0] ).to eql 'create'
        expect( tuple[1] ).to include :_index => 'logs-generic-default'
      end

    end

  end

  describe "field sync" do

    let(:options) { super().merge('data_stream' => 'true') }

    let(:do_register) { true }

    let(:event) do
      event = LogStash::Event.new
      event.set '[host][hostname]', 'orangutan'
      event
    end

    context 'enabled and no event data' do

      let(:options) { super().merge('data_stream_sync_fields' => 'true') }

      it 'fills in DS fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({"type" => "logs", "dataset" => "generic", "namespace" => "default"})
      end

    end

    context 'enabled and some event data' do

      let(:options) { super().merge('data_stream_dataset' => 'ds1', 'data_stream_sync_fields' => 'true') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][namespace]', 'custom'
        end
      end

      it 'fills in missing fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({"type" => "logs", "dataset" => "ds1", "namespace" => "custom"})
      end

      it 'does not mutate data_stream hash' do
        data_stream = event.get('data_stream')
        data_stream_dup = data_stream.dup
        subject.map_events([ event ])
        expect( data_stream ).to eql data_stream_dup
      end

    end

    context 'enabled with invalid data' do

      let(:options) { super().merge('data_stream_sync_fields' => 'true') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream]', false
        end
      end

      it 'overwrites invalid data_stream field' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({"type" => "logs", "dataset" => "generic", "namespace" => "default"})
      end

    end

    context 'enabled having invalid data with routing disabled' do

      let(:options) do
        super().merge('data_stream_sync_fields' => 'true', 'data_stream_auto_routing' => 'false', 'data_stream_namespace' => 'ns1')
      end

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][type]', 'foo'
          event.set '[data_stream][dataset]', false
          event.set '[data_stream][extra]', 0
        end
      end

      it 'overwrites invalid data_stream sub-fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({"type" => "logs", "dataset" => "generic", "namespace" => "ns1", "extra" => 0})
      end

    end

    context 'disabled and no event data' do

      let(:options) { super().merge('data_stream_dataset' => 'ds1', 'data_stream_sync_fields' => 'false') }

      it 'does not fill DS fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2].keys ).to_not include 'data_stream'
      end

    end

    context 'disabled and some event data' do

      let(:options) { super().merge('data_stream_sync_fields' => 'false') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream][type]', 'logs'
        end
      end

      it 'does not fill DS fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({ 'type' => 'logs'})
      end

    end

  end

  describe "validation" do

    context 'with too long dataset name' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_dataset' => 'x' * 120) }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

    context 'with empty dataset name' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_dataset' => '') }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

    context 'with invalid dataset char' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_dataset' => 'foo/bar') }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

    context 'with invalid namespace char' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_namespace' => 'foo*') }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

    context 'with invalid "empty" namespace' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_namespace' => ' ') }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

    context 'with invalid type' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_type' => 'custom') }

      it 'fails' do
        expect { LogStash::Outputs::ElasticSearch.new(options) }.to raise_error LogStash::ConfigurationError
      end

    end

  end

  private

  def change_constant(name, new_value, target: Object)
    old_value = target.const_get name
    begin
      target.send :remove_const, name
      target.const_set name, new_value
      yield if block_given?
    ensure
      if block_given?
        target.send :remove_const, name rescue nil
        target.const_set name, old_value
      end
    end
  end

end
