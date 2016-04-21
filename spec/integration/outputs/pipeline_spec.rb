require_relative "../../../spec/es_spec_helper"

describe "Ingest pipeline execution behavior", :integration => true do
  subject! do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "#{get_host_port()}"
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

    # TODO(talevy): make these comments real
    # PUT a new ingest pipeline definition into ES
    # {
    #   "description": "test pipeline that inserts a field",
    #   "processors" : [
    #     {
    #       "set" : {
    #         "ingest_field": "foo"
    #       }
    #     }
    #   ]
    # }

    subject.register
    subject.receive(LogStash::Event.new("magic_field" => "magic"))
    subject.flush
    @es.indices.refresh

    # Wait or fail until everything's indexed.
    Stud::try(20.times) do
      r = @es.search
      insist { r["hits"]["total"] } == 1
    end
  end

  # TODO(talevy): only run this when ENV['ES_VERSION'] ~= 5.*
  it "indexes using the proper pipeline" do
    results = @es.search(:q => "magic_field:\"magic\"")
    insist { results["hits"]["total"] } == 1
    insist { results["hits"]["hits"][0]["_source"]["magic_field"] } == "magic"
    insist { results["hits"]["hits"][0]["_source"]["ingest_field"] } == "foo"
  end
end
