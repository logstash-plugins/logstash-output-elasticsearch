require "logstash/outputs/elasticsearch"
require_relative "../../../spec/es_spec_helper"

describe "elasticsearch is down on startup", :integration => true do
  let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
  let(:event2) { LogStash::Event.new("message" => "a") }

  subject {
    LogStash::Outputs::ElasticSearch.new({
                                           "manage_template" => true,
                                           "index" => "logstash-2014.11.17",
                                           "template_overwrite" => true,
                                           "hosts" => get_host_port(),
                                           "retry_max_interval" => 64,
                                           "retry_initial_interval" => 2,
                                           'ecs_compatibility' => 'disabled'
                                       })
  }

  before :each do
    # Delete all templates first.
    allow(Stud).to receive(:stoppable_sleep)

    # Clean ES of data before we start.
    @es = get_client
    @es.indices.delete_template(:name => "*")
    @es.indices.delete(:index => "*")
    @es.indices.refresh
  end

  after :each do
    subject.close
  end

  it 'should ingest events when Elasticsearch recovers before documents are sent' do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_root_path).with(any_args).and_raise(
        ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new StandardError.new("TEST: before docs are sent"), 'http://test.es/'
    )
    subject.register
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_root_path).with(any_args).and_call_original
    subject.multi_receive([event1, event2])
    @es.indices.refresh
    r = @es.search(index: 'logstash-*')
    expect(r).to have_hits(2)
  end

  it 'should ingest events when Elasticsearch recovers after documents are sent' do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_root_path).with(any_args).and_raise(
        ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new StandardError.new("TEST: after docs are sent"), 'http://test.es/'
    )
    subject.register
    Thread.new do
      sleep 4
      allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_root_path).with(any_args).and_call_original
    end
    subject.multi_receive([event1, event2])
    @es.indices.refresh
    r = @es.search(index: 'logstash-*')
    expect(r).to have_hits(2)
  end

  it 'should get cluster_uuid when Elasticsearch recovers from license check failure' do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_license).and_raise(
        ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new StandardError.new("TEST: docs are sent"), 'http://test.es/_license'
    )
    subject.register
    Thread.new do
      sleep 4
      allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_license).and_call_original
    end
    subject.multi_receive([event1, event2])
    @es.indices.refresh
    r = @es.search(index: 'logstash-*')
    expect(r).to have_hits(2)
    expect(subject.plugin_metadata.get(:cluster_uuid)).not_to be_empty
    expect(subject.plugin_metadata.get(:cluster_uuid)).not_to eq("_na_")
  end if ESHelper.es_version_satisfies?(">=7")
end
