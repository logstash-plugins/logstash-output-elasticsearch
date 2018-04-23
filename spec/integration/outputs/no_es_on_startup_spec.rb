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
                                           "retry_initial_interval" => 2
                                       })
  }

  before :each do
    # Delete all templates first.
    require "elasticsearch"
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
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_es_version).and_raise(::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new(StandardError.new, "big fail"))
    subject.register
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_es_version).and_return(ESHelper.es_version)
    subject.multi_receive([event1, event2])
    @es.indices.refresh
    r = @es.search
    expect(r["hits"]["total"]).to eql(2)
  end

  it 'should ingest events when Elasticsearch recovers after documents are sent' do
    allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_es_version).and_raise(::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new(StandardError.new, "big fail"))
    subject.register
    Thread.new do
      sleep 4
      allow_any_instance_of(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:get_es_version).and_return(ESHelper.es_version)
    end
    subject.multi_receive([event1, event2])
    @es.indices.refresh
    r = @es.search
    expect(r["hits"]["total"]).to eql(2)
  end

end
