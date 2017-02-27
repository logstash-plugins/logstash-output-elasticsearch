require_relative "../../../spec/es_spec_helper"

# This file is a copy of template test for 2.x. We can DRY this up later.
describe "index template expected behavior for 5.x", :integration => true, :version_greater_than_equal_to_5x => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "manage_template" => true,
      "template_overwrite" => true,
      "hosts" => "#{get_host_port()}"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    send_delete_all

    subject.register

    subject.multi_receive([
      LogStash::Event.new("message" => "sample message here"),
      LogStash::Event.new("somemessage" => { "message" => "sample nested message here" }),
      LogStash::Event.new("somevalue" => 100),
      LogStash::Event.new("somevalue" => 10),
      LogStash::Event.new("somevalue" => 1),
      LogStash::Event.new("country" => "us"),
      LogStash::Event.new("country" => "at"),
      LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
    ])

    send_refresh
    
    # Wait or fail until everything's indexed.
    Stud::try(20.times) do
      r = search_query_string("*")
      expect(r["hits"]["total"]).to eq(8)
    end
  end

  it "permits phrase searching on string fields" do
    results = search_query_string("message:\"sample message\"")
    expect(results["hits"]["total"]).to eq(1)
    expect(results["hits"]["hits"][0]["_source"]["message"]).to eq("sample message here")
  end

  it "numbers dynamically map to a numeric type and permit range queries" do
    results = search_query_string("somevalue:[5 TO 105]")
    expect(results["hits"]["total"]).to eq(2)

    values = results["hits"]["hits"].collect { |r| r["_source"]["somevalue"] }
    expect(values).to include(10)
    expect(values).to include(100)
    expect(values).not_to include(1)
  end

  it "does not create .keyword field for top-level message field" do
    results = search_query_string("message.keyword:\"sample message here\"")
    expect(results["hits"]["total"]).to eq(0)
  end

  it "creates .keyword field for nested message fields" do
    results = search_query_string("somemessage.message.keyword:\"sample nested message here\"")
    expect(results["hits"]["total"]).to eq(1)
  end

  it "creates .keyword field from any string field which is not_analyzed" do
    results = search_query_string("country.keyword:\"us\"")
    expect(results["hits"]["total"]).to eq(1)
    expect(results["hits"]["hits"][0]["_source"]["country"]).to eq("us")

    # partial or terms should not work.
    results = search_query_string("country.keyword:\"u\"")
    expect(results["hits"]["total"]).to eq(0)
  end

  it "make [geoip][location] a geo_point" do
    tmpl = send_json_request(:get, "/_template/logstash")
    expect(tmpl["logstash"]["mappings"]["_default_"]["properties"]["geoip"]["properties"]["location"]["type"]).to eq("geo_point")
  end

  it "aggregate .keyword results correctly " do
    search_body = { 
      "aggregations" => {
        "my_agg" => { 
          "terms" => { 
            "field" => "country.keyword" 
          } 
        }
      }
    }
    results = send_json_request(:get, "/_search", :body => search_body)["aggregations"]["my_agg"]
    terms = results["buckets"].collect { |b| b["key"] }

    expect(terms).to include("us")

    # 'at' is a stopword, make sure stopwords are not ignored.
    expect(terms).to include("at")
  end
end
