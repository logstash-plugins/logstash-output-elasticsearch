require_relative "../../../spec/es_spec_helper"

describe "index template expected behavior", :integration => true, :version_less_than_5x => true do
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
    # Clean ES of data before we start.
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

    # Wait or fail until everything's indexed.
    r = search_query_string("*")
    expect(r["hits"]["total"]).to eq(8)
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

  it "does not create .raw field for the message field" do
    results = search_query_string("message.raw:\"sample message here\"")
    expect(results["hits"]["total"]).to eq(0)
  end

  it "creates .raw field for nested message fields" do
    results = search_query_string("somemessage.message.raw:\"sample nested message here\"")
    expect(results["hits"]["total"]).to eq(1)
  end

  it "creates .raw field from any string field which is not_analyzed" do
    results = search_query_string("country.raw:\"us\"")
    expect(results["hits"]["total"]).to eq(1)
    expect(results["hits"]["hits"][0]["_source"]["country"]).to eq("us")

    # partial or terms should not work.
    results = search_query_string("country.raw:\"u\"")
    expect(results["hits"]["total"]).to eq(0)
  end

  it "make [geoip][location] a geo_point" do
    tmpl = send_json_request("/_template/logstash")
    expect(tmpl["logstash"]["mappings"]["_default_"]["properties"]["geoip"]["properties"]["location"]["type"]).to eq("geo_point")
  end

  it "aggregate .raw results correctly " do
    results = send_json_request(:get, "/_search", :body => { "aggregations" => { "my_agg" => { "terms" => { "field" => "country.raw" } } } })["aggregations"]["my_agg"]
    terms = results["buckets"].collect { |b| b["key"] }

    insist { terms }.include?("us")

    # 'at' is a stopword, make sure stopwords are not ignored.
    insist { terms }.include?("at")
  end
end
