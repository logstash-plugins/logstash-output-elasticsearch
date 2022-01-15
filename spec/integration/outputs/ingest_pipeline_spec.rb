require_relative "../../../spec/es_spec_helper"

describe "Ingest pipeline execution behavior", :integration => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "#{get_host_port()}",
      "pipeline" => "apache-logs",
      "data_stream" => 'false',
      "ecs_compatibility" => "disabled", # specs are tightly tied to non-ECS defaults
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  let(:http_client) { Manticore::Client.new }
  let(:ingest_url) { "http://#{get_host_port()}/_ingest/pipeline/apache-logs" }
  let(:apache_logs_pipeline) { '
  {
    "description" : "Pipeline to parse Apache logs",
    "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{COMBINEDAPACHELOG}"]
        }
      }
    ]
  }'
  }

  before :each do
    # Delete all templates first.
    require "elasticsearch"

    # Clean ES of data before we start.
    @es = get_client
    @es.indices.delete_template(:name => "*")

    # This can fail if there are no indexes, ignore failure.
    @es.indices.delete(:index => "*") rescue nil

    # delete existing ingest pipeline
    http_client.delete(ingest_url).call

    # register pipeline
    http_client.put(ingest_url, :body => apache_logs_pipeline, :headers => {"Content-Type" => "application/json" }).call

    #TODO: Use esclient
    #@es.ingest.put_pipeline :id => 'apache_pipeline', :body => pipeline_defintion

    subject.register
    subject.multi_receive([LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"')])
    @es.indices.refresh

    #Wait or fail until everything's indexed.
    Stud::try(10.times) do
      r = @es.search(index: 'logstash-*')
      expect(r).to have_hits(1)
      sleep(0.1)
    end
  end

  it "indexes using the proper pipeline" do
    results = @es.search(:index => "logstash-*", :q => "message:\"netcat\"")
    expect(results).to have_hits(1)
    expect(results["hits"]["hits"][0]["_source"]["response"]).to eq("200")
    expect(results["hits"]["hits"][0]["_source"]["bytes"]).to eq("182")
    expect(results["hits"]["hits"][0]["_source"]["verb"]).to eq("GET")
    expect(results["hits"]["hits"][0]["_source"]["request"]).to eq("/scripts/netcat-webserver")
    expect(results["hits"]["hits"][0]["_source"]["auth"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["ident"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["clientip"]).to eq("183.60.215.50")
    expect(results["hits"]["hits"][0]["_source"]["junkfieldaaaa"]).to eq(nil)
  end
end

describe "Ingest pipeline from metadata", :integration => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "#{get_host_port()}",
      "pipeline" => "apache-logs",
      "data_stream" => "false",
      "use_metadata" => true,
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  let(:http_client) { Manticore::Client.new }
  let(:ingest_url) { "http://#{get_host_port()}/_ingest/pipeline/apache-logs" }
  let(:apache_logs_pipeline) {
    '
  {
    "description" : "Pipeline to parse Apache logs",
    "processors" : [
      {
        "grok": {
          "field": "message",
          "patterns": ["%{COMBINEDAPACHELOG}"]
        }
      }
    ]
  }'
  }

  let(:add_field_ingest_url) { "http://#{get_host_port()}/_ingest/pipeline/add-field" }
  let(:add_field_logs_pipeline) {
    '
  {
    "description": "Add field foo with value bar",
    "processors": [
      {
        "set": {
          "field": "foo",
          "value": "bar"
        }
      }
    ]
  }'
  }

  before :each do
    # Delete all templates first.
    require "elasticsearch"

    # Clean ES of data before we start.
    @es = get_client
    @es.indices.delete_template(:name => "*")

    # This can fail if there are no indexes, ignore failure.
    @es.indices.delete(:index => "*") rescue nil

    # delete existing ingest pipeline
    http_client.delete(ingest_url).call

    # register pipelines
    http_client.put(ingest_url, :body => apache_logs_pipeline, :headers => { "Content-Type" => "application/json" }).call
    http_client.put(add_field_ingest_url, :body => add_field_logs_pipeline, :headers => { "Content-Type" => "application/json" }).call

    #TODO: Use esclient
    #@es.ingest.put_pipeline :id => 'apache_pipeline', :body => pipeline_defintion

    subject.register
    subject.multi_receive([
      LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"'),
      LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"', "@metadata" => { "_id" => "id1", "_index" => "index1", "pipeline" => "add-field" }),
      LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"', "@metadata" => { "_id" => "id2", "_index" => "index2", "pipeline" => "" }),
    ])
    @es.indices.refresh

    #Wait or fail until everything's indexed.
    Stud::try(10.times) do
      r = @es.search(index: "logstash-*")
      expect(r).to have_hits(1)
      r = @es.search(index: "index1")
      expect(r).to have_hits(1)
      r = @es.search(index: "index2")
      expect(r).to have_hits(1)
      sleep(0.1)
    end
  end

  it "indexes using the correct pipeline when @metadata.pipeline not defined" do
    results = @es.search(:index => "logstash-*", :q => "message:\"netcat\"")
    expect(results).to have_hits(1)
    expect(results["hits"]["hits"][0]["_source"]["response"]).to eq("200")
    expect(results["hits"]["hits"][0]["_source"]["bytes"]).to eq("182")
    expect(results["hits"]["hits"][0]["_source"]["verb"]).to eq("GET")
    expect(results["hits"]["hits"][0]["_source"]["request"]).to eq("/scripts/netcat-webserver")
    expect(results["hits"]["hits"][0]["_source"]["auth"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["ident"]).to eq("-")
    expect(results["hits"]["hits"][0]["_source"]["clientip"]).to eq("183.60.215.50")
    expect(results["hits"]["hits"][0]["_source"]["junkfieldaaaa"]).to eq(nil)
  end

  it "indexes using the @metadata._index, @metadata._id, and @metadata.pipeline when defined" do
    results = @es.search(:index => "index1", :q => "message:\"netcat\"")
    expect(results).to have_hits(1)
    expect(results["hits"]["hits"][0]["_id"]).to eq("id1")
    expect(results["hits"]["hits"][0]["_index"]).to eq("index1")
    expect(results["hits"]["hits"][0]["_source"]["foo"]).to eq("bar")
  end

  it "indexes ignore empty @metadata.pipeline values" do
    results = @es.search(:index => "index2", :q => "message:\"netcat\"")
    expect(results).to have_hits(1)
    expect(results["hits"]["hits"][0]["_id"]).to eq("id2")
    expect(results["hits"]["hits"][0]["_index"]).to eq("index2")
    expect(results["hits"]["hits"][0]["_source"]).not_to include("foo")
  end

end
