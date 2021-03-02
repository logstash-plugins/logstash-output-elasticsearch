require_relative '../../../../spec/spec_helper'
require "logstash/outputs/elasticsearch/data_stream_support"

describe LogStash::Outputs::ElasticSearch::DataStreamSupport do

  subject { LogStash::Outputs::ElasticSearch.new(options) }
  let(:options) { { 'hosts' => [ 'localhost:12345' ] } }
  let(:es_version) { '7.10.1' }

  let(:do_register) { false }

  @@logstash_oss = LogStash::OSS

  before(:each) do
    change_constant :OSS, false, target: LogStash # assume non-OSS by default

    if do_register
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
    end
  end

  after(:each) do
    subject.close if do_register

    change_constant :OSS, @@logstash_oss, target: LogStash
  end

  context "default configuration" do

    let(:options) { {} }

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does not use data-streams on LS 7.x" do
      change_constant :LOGSTASH_VERSION, '7.10.0' do
        expect( subject.data_stream_config? ).to be false
      end
    end

    it "defaults to using data-streams on LS 8.0" do
      change_constant :LOGSTASH_VERSION, '8.0.0' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    context 'non-compatible ES' do

      let(:es_version) { '7.8.1' }

      it "raises when running on LS 8.0" do
        change_constant :LOGSTASH_VERSION, '8.0.0' do
          error_message = /data_stream is only supported since Elasticsearch 7.9.0 \(detected version 7.8.1\)/
          expect { subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, error_message)
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

    it "warns about not using data-streams on LS 8.0 (OSS)" do
      expect( subject.logger ).to receive(:warn) do |msg|
        msg.index "Configuration is data_stream compliant but won't be used"
      end
      change_constant :LOGSTASH_VERSION, '8.0.1' do
        change_constant :OSS, true, target: LogStash do
          expect( subject.data_stream_config? ).to be false
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

  end


  context "(explicit) ds enabled configuration" do

    let(:options) { super().merge('data_stream' => true.to_s) }

    before { allow(subject).to receive(:last_es_version).and_return(es_version) }

    it "does use data-streams on LS 7.x" do
      change_constant :LOGSTASH_VERSION, '7.9.1' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    it "does use data-streams on LS 8.0" do
      change_constant :LOGSTASH_VERSION, '8.1.0' do
        expect( subject.data_stream_config? ).to be true
      end
    end

    context 'non-compatible ES' do

      let(:es_version) { '6.8.11' }

      it "raises when running on LS 8.0" do
        change_constant :LOGSTASH_VERSION, '8.0.0' do
          error_message = /data_stream is only supported since Elasticsearch 7.9.0 \(detected version 6.8.11\)/
          expect { subject.data_stream_config? }.to raise_error(LogStash::ConfigurationError, error_message)
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

    let(:do_register) { true }

    let(:event) do
      event = LogStash::Event.new
      event.set '[host][hostname]', 'orangutan'
      event
    end

    context 'enabled and no event data' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_sync_fields' => 'true') }

      it 'fills in DS fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql({"type" => "logs", "dataset" => "generic", "namespace" => "default"})
      end

    end

    context 'enabled and some event data' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_dataset' => 'ds1', 'data_stream_sync_fields' => 'true') }

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

    end

    context 'enabled with invalid data' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_sync_fields' => 'true') }

      let(:event) do
        super().tap do |event|
          event.set '[data_stream]', false
        end
      end

      it 'does not fill ds fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2]['data_stream'] ).to eql(false)
      end

    end

    context 'disabled and no event data' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_dataset' => 'ds1', 'data_stream_sync_fields' => 'false') }

      it 'does not fill DS fields' do
        tuple = subject.map_events([ event ]).first
        expect( tuple.size ).to eql 3
        expect( tuple[2].keys ).to_not include 'data_stream'
      end

    end

    context 'disabled and some event data' do

      let(:options) { super().merge('data_stream' => 'true', 'data_stream_sync_fields' => 'false') }

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
