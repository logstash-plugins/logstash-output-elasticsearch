require_relative "../../../spec/es_spec_helper"

describe "Ingest pipeline execution behavior", :integration_5x => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "#{get_host_port()}",
      "pipeline" => "apache-logs"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  let(:ftw_client) { FTW::Agent.new }
  let(:ingest_url) { "http://#{get_host_port()}/_ingest/pipeline/apache-logs" }
  let(:apache_logs_pipeline) { '
    {
      "description" : "Pipeline to parse Apache logs",
      "processors" : [
        {
          "grok": {
            "field": "message",
            "pattern": "%{COMBINEDAPACHELOG}"
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
    req = ftw_client.delete(ingest_url)
    ftw_client.execute(req)

    # register pipeline
    req = ftw_client.put(ingest_url, :body => apache_logs_pipeline)
    ftw_client.execute(req)

    #TODO: Use esclient
    #@es.ingest.put_pipeline :id => 'apache_pipeline', :body => pipeline_defintion

    subject.register
    subject.multi_receive([LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"')])
    @es.indices.refresh

    #Wait or fail until everything's indexed.
    Stud::try(20.times) do
      r = @es.search
      insist { r["hits"]["total"] } == 1
    end
  end

  it "indexes using the proper pipeline" do
    results = @es.search(:index => 'logstash-*', :q => "message:\"netcat\"")
    insist { results["hits"]["total"] } == 1
    insist { results["hits"]["hits"][0]["_source"]["response"] } == "200"
    insist { results["hits"]["hits"][0]["_source"]["bytes"] } == "182"
    insist { results["hits"]["hits"][0]["_source"]["verb"] } == "GET"
    insist { results["hits"]["hits"][0]["_source"]["request"] } == "/scripts/netcat-webserver"
    insist { results["hits"]["hits"][0]["_source"]["auth"] } == "-"
    insist { results["hits"]["hits"][0]["_source"]["ident"] } == "-"
    insist { results["hits"]["hits"][0]["_source"]["clientip"] } == "183.60.215.50"
    insist { results["hits"]["hits"][0]["_source"]["junkfieldaaaa"] } == nil
  end
end
