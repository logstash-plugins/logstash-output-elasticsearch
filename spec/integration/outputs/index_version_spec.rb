require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"

describe "Versioned indexing", :integration => true do
  require "logstash/outputs/elasticsearch"

  let(:es) { get_client }

  before :each do
    # Delete all templates first.
    # Clean ES of data before we start.
    es.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    es.indices.delete(:index => "*") rescue nil
    es.indices.refresh
  end

  context "when index only" do
    subject { LogStash::Outputs::ElasticSearch.new(settings) }

    before do
      subject.register
    end

    describe "unversioned output" do
      let(:settings) do
        {
          "manage_template" => true,
          "index" => "logstash-index",
          "template_overwrite" => true,
          "hosts" => get_host_port(),
          "action" => "index",
          "document_id" => "%{my_id}"
        }
      end

      it "should default to ES version" do
        subject.multi_receive([LogStash::Event.new("my_id" => "123", "message" => "foo")])
        r = es.get(generate_common_index_params('logstash-index', '123'))
        expect(r["_version"]).to eq(1)
        expect(r["_source"]["message"]).to eq('foo')
        subject.multi_receive([LogStash::Event.new("my_id" => "123", "message" => "foobar")])
        r2 = es.get(generate_common_index_params('logstash-index', '123'))
        expect(r2["_version"]).to eq(2)
        expect(r2["_source"]["message"]).to eq('foobar')
      end  
    end

    describe "versioned output" do
      let(:settings) do 
        {
          "manage_template" => true,
          "index" => "logstash-index",
          "template_overwrite" => true,
          "hosts" => get_host_port(),
          "action" => "index",
          "document_id" => "%{my_id}",
          "version" => "%{my_version}",
          "version_type" => "external",
        }
      end

      it "should respect the external version" do
        id = "ev1"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = es.get(generate_common_index_params('logstash-index', id))
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')
      end

      it "should ignore non-monotonic external version updates" do
        id = "ev2"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = es.get(generate_common_index_params('logstash-index', id))
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')

        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "98", "message" => "foo")])
        r2 = es.get(generate_common_index_params('logstash-index', id))
        expect(r2["_version"]).to eq(99)
        expect(r2["_source"]["message"]).to eq('foo')
      end

      it "should commit monotonic external version updates" do
        id = "ev3"
        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "99", "message" => "foo")])
        r = es.get(generate_common_index_params('logstash-index', id))
        expect(r["_version"]).to eq(99)
        expect(r["_source"]["message"]).to eq('foo')

        subject.multi_receive([LogStash::Event.new("my_id" => id, "my_version" => "100", "message" => "foo")])
        r2 = es.get(generate_common_index_params('logstash-index', id))
        expect(r2["_version"]).to eq(100)
        expect(r2["_source"]["message"]).to eq('foo')
      end
    end
  end
end
