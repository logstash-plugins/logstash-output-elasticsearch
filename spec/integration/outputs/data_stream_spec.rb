require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"

describe "data streams", :integration => true do

  let(:ds_name) { "logs-#{ds_dataset}-default" }
  let(:ds_dataset) { 'integration_test' }

  let(:options) do
    { "data_stream" => 'true', "data_stream_dataset" => ds_dataset, "hosts" => get_host_port() }
  end

  subject { LogStash::Outputs::ElasticSearch.new(options) }

  before :each do
    @es = get_client
    @es.delete_by_query(index: ".ds-#{ds_name}-*", expand_wildcards: :all, body: { query: { match_all: {} } }) rescue nil

    es_version = @es.info['version']['number']
    if Gem::Version.create(es_version) < Gem::Version.create('7.9.0')
      pending "ES version #{es_version} does not support data-streams"
    end
  end

  it "creates a new document" do
    subject.register
    subject.multi_receive([LogStash::Event.new("message" => "MSG 111")])

    @es.indices.refresh

    Stud::try(3.times) do
      r = @es.search(index: ds_name)

      expect( r['hits']['total']['value'] ).to eq 1
      doc = r['hits']['hits'].first
      expect( doc['_source'] ).to include "message"=>"MSG 111"
      expect( doc['_source'] ).to include "data_stream"=>{"dataset"=>ds_dataset, "type"=>"logs", "namespace"=>"default"}
    end
  end

  context "with document_id" do

    let(:document_id) { '1234567890' }
    let(:options) { super().merge("document_id" => document_id) }

    it "creates a new document" do
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "foo")])

      @es.indices.refresh

      Stud::try(3.times) do
        r = @es.search(index: ds_name, body: { query: { match: { _id: document_id } } })
        expect( r['hits']['total']['value'] ).to eq 1
        doc = r['hits']['hits'].first
        expect( doc['_source'] ).to include "message"=>"foo"
      end
    end

  end
end
