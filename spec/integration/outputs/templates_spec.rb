require_relative "../../../spec/es_spec_helper"

describe "index template expected behavior", :integration => true do
  let(:ecs_compatibility) { fail('spec group does not define `ecs_compatibility`!') }

  subject! do
    require "logstash/outputs/elasticsearch"
    allow_any_instance_of(LogStash::Outputs::ElasticSearch).to receive(:ecs_compatibility).and_return(ecs_compatibility)

    settings = {
      "manage_template" => true,
      "template_overwrite" => true,
      "hosts" => "#{get_host_port()}"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  let(:elasticsearch_client) { get_client }

  before(:each) do
    # delete indices and templates
    require "elasticsearch"

    elasticsearch_client.indices.delete_template(:name => '*')
    # This can fail if there are no indexes, ignore failure.
    elasticsearch_client.indices.delete(:index => '*') rescue nil
  end

  context 'with ecs_compatibility => disabled' do
    let(:ecs_compatibility) { :disabled }
    before :each do
      @es = elasticsearch_client # cache as ivar for tests...

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

      @es.indices.refresh

      # Wait or fail until everything's indexed.
      Stud::try(20.times) do
        r = @es.search(index: 'logstash*')
        expect(r).to have_hits(8)
      end
    end

    it "permits phrase searching on string fields" do
      results = @es.search(index: 'logstash*', q: "message:\"sample message\"")
      expect(results).to have_hits(1)
      expect(results["hits"]["hits"][0]["_source"]["message"]).to eq("sample message here")
    end

    it "numbers dynamically map to a numeric type and permit range queries" do
      results = @es.search(index: 'logstash*', q: "somevalue:[5 TO 105]")
      expect(results).to have_hits(2)

      values = results["hits"]["hits"].collect { |r| r["_source"]["somevalue"] }
      expect(values).to include(10)
      expect(values).to include(100)
      expect(values).to_not include(1)
    end

    it "does not create .keyword field for top-level message field" do
      results = @es.search(index: 'logstash*', q: "message.keyword:\"sample message here\"")
      expect(results).to have_hits(0)
    end

    it "creates .keyword field for nested message fields" do
      results = @es.search(index: 'logstash*', q: "somemessage.message.keyword:\"sample nested message here\"")
      expect(results).to have_hits(1)
    end

    it "creates .keyword field from any string field which is not_analyzed" do
      results = @es.search(index: 'logstash*', q: "country.keyword:\"us\"")
      expect(results).to have_hits(1)
      expect(results["hits"]["hits"][0]["_source"]["country"]).to eq("us")

      # partial or terms should not work.
      results = @es.search(index: 'logstash*', q: "country.keyword:\"u\"")
      expect(results).to have_hits(0)
    end

    it "make [geoip][location] a geo_point" do
      expect(field_properties_from_template("logstash", "geoip")["location"]["type"]).to eq("geo_point")
    end

    it "aggregate .keyword results correctly " do
      results = @es.search(index: 'logstash*', body: { "aggregations" => { "my_agg" => { "terms" => { "field" => "country.keyword" } } } })["aggregations"]["my_agg"]
      terms = results["buckets"].collect { |b| b["key"] }

      expect(terms).to include("us")

      # 'at' is a stopword, make sure stopwords are not ignored.
      expect(terms).to include("at")
    end
  end

  context 'with ECS enabled' do
    let(:ecs_compatibility) { :v1 }

    before(:each) do
      subject.register # should load template?
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
    end

    let(:elasticsearch_cluster_major_version) do
      elasticsearch_client.info&.dig("version", "number" )&.split('.')&.map(&:to_i)&.first
    end

    it 'loads the templates' do
      aggregate_failures do
        if elasticsearch_cluster_major_version >= 8
          # In ES 8+ we use the _index_template API
          expect(elasticsearch_client.indices.exists_index_template(name: 'ecs-logstash')).to be_truthy
        else
          # Otherwise, we used the legacy _template API
          expect(elasticsearch_client.indices.exists_template(name: 'ecs-logstash')).to be_truthy
        end
      end
    end
  end
end
