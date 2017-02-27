require_relative "../../../spec/es_spec_helper"

describe "Ingest pipeline execution behavior", :integration => true, :version_greater_than_equal_to_5x => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "#{get_host_port()}",
      "pipeline" => "apache-logs"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

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
    send_delete_all

    # delete existing ingest pipeline
    send_request(:delete, ingest_url)

    # register pipeline
    send_request(:put, ingest_url, :body => apache_logs_pipeline)

    subject.register
    subject.multi_receive([LogStash::Event.new("message" => '183.60.215.50 - - [01/Jun/2015:18:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"')])
    send_refresh

    r = search_query_string("*")
    expect(r["hits"]["total"]).to eq(1)
  end

  it "indexes using the proper pipeline" do
    results = send_json_request(:post, "/logstash-*/_search", :query => {:q => "message:\"netcat\""})
    
    expect(results["hits"]["total"]).to eq(1)
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
