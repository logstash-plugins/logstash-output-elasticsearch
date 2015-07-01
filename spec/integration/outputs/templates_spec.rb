require_relative "../../../spec/es_spec_helper"

describe "index template expected behavior", :integration => true do
  ["transport", "http"].each do |protocol|
    context "with protocol => #{protocol}" do
        
      subject! do
        require "logstash/outputs/elasticsearch"
        settings = {
          "manage_template" => true,
          "template_overwrite" => true,
          "protocol" => protocol,
          "host" => "#{get_host()}",
          "port" => "#{get_port(protocol)}"
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      before :each do
        # Delete all templates first.
        require "elasticsearch"

        # Clean ES of data before we start.
        @es = get_client
        @es.indices.delete_template(:name => "*")

        # This can fail if there are no indexes, ignore failure.
        @es.indices.delete(:index => "*") rescue nil

        subject.register

        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.receive(LogStash::Event.new("somevalue" => 100))
        subject.receive(LogStash::Event.new("somevalue" => 10))
        subject.receive(LogStash::Event.new("somevalue" => 1))
        subject.receive(LogStash::Event.new("country" => "us"))
        subject.receive(LogStash::Event.new("country" => "at"))
        subject.receive(LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] }))
        subject.buffer_flush(:final => true)
        @es.indices.refresh

        # Wait or fail until everything's indexed.
        Stud::try(20.times) do
          r = @es.search
          insist { r["hits"]["total"] } == 7
        end
      end

      it "permits phrase searching on string fields" do
        results = @es.search(:q => "message:\"sample message\"")
        insist { results["hits"]["total"] } == 1
        insist { results["hits"]["hits"][0]["_source"]["message"] } == "sample message here"
      end

      it "numbers dynamically map to a numeric type and permit range queries" do
        results = @es.search(:q => "somevalue:[5 TO 105]")
        insist { results["hits"]["total"] } == 2

        values = results["hits"]["hits"].collect { |r| r["_source"]["somevalue"] }
        insist { values }.include?(10)
        insist { values }.include?(100)
        reject { values }.include?(1)
      end

      it "does not create .raw field for the message field" do
        results = @es.search(:q => "message.raw:\"sample message here\"")
        insist { results["hits"]["total"] } == 0
      end

      it "creates .raw field from any string field which is not_analyzed" do
        results = @es.search(:q => "country.raw:\"us\"")
        insist { results["hits"]["total"] } == 1
        insist { results["hits"]["hits"][0]["_source"]["country"] } == "us"

        # partial or terms should not work.
        results = @es.search(:q => "country.raw:\"u\"")
        insist { results["hits"]["total"] } == 0
      end

      it "make [geoip][location] a geo_point" do
        results = @es.search(:body => { "filter" => { "geo_distance" => { "distance" => "1000km", "geoip.location" => { "lat" => 0.5, "lon" => 0.5 } } } })
        insist { results["hits"]["total"] } == 1
        insist { results["hits"]["hits"][0]["_source"]["geoip"]["location"] } == [ 0.0, 0.0 ]
      end

      it "should index stopwords like 'at' " do
        results = @es.search(:body => { "aggregations" => { "my_agg" => { "terms" => { "field" => "country" } } } })["aggregations"]["my_agg"]
        terms = results["buckets"].collect { |b| b["key"] }

        insist { terms }.include?("us")

        # 'at' is a stopword, make sure stopwords are not ignored.
        insist { terms }.include?("at")
      end
    end
  end
end
