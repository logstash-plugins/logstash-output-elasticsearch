require_relative '../../../../spec/spec_helper'
require "logstash/outputs/elasticsearch"

describe LogStash::Outputs::ElasticSearch::DataStreamSupport do

  subject { LogStash::Outputs::ElasticSearch.new(options) }
  let(:options) { { 'hosts' => [ 'localhost:12345' ] } }
  let(:es_version) { '7.10.1' }

  let(:do_register) { false }

  @@logstash_oss = LogStash::OSS

  before(:each) do
    change_constant :OSS, false, target: LogStash # assume non-OSS by default

    allow(subject).to receive(:last_es_version).and_return(es_version)

    if do_register
      stub_client(subject)
      allow(subject.client).to receive(:maximum_seen_major_version).and_return(Integer(es_version.split('.').first))

      # stub-out unrelated (finish_register) setup:
      allow(subject).to receive(:discover_cluster_uuid)
      allow(subject).to receive(:install_template)
      allow(subject).to receive(:ilm_in_use?).and_return nil

      subject.register
    end
  end

  after(:each) do
    subject.close if do_register

    change_constant :OSS, @@logstash_oss, target: LogStash
  end

  context "default configuration" do

    let(:options) { {} }

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

    let(:options) { super.merge('data_stream' => false.to_s) }

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

    let(:options) { super.merge('data_stream' => true.to_s) }

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

    let(:options) { super.merge('data_stream' => 'true') }
    let(:do_register) { true }

    let(:event) do
      event = LogStash::Event.new
      event.set '[host][hostname]', 'orangutan'
      event
    end

    context 'with data_stream.* event data' do

      let(:event) do
        super.tap do |event|
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

      let(:options) { super.merge('data_stream_auto_routing' => 'false') }

      let(:event) do
        super.tap do |event|
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

      let(:options) { super.merge('data_stream_dataset' => 'data') }

      let(:event) do
        super.tap do |event|
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

      let(:options) { super.merge('data_stream_dataset' => 'stats', 'data_stream_type' => 'metrics') }

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
