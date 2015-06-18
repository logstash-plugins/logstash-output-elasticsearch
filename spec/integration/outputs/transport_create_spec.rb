require_relative "../../../spec/es_spec_helper"

describe "transport client create actions", :integration => true do
  require "logstash/outputs/elasticsearch"
  require "elasticsearch"

  def get_es_output(action, id = nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-create",
      "template_overwrite" => true,
      "protocol" => "transport",
      "host" => get_host(),
      "port" => get_port('transport'),
      "action" => action
    }
    settings['document_id'] = id unless id.nil?
    LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    @es = get_client
    # Delete all templates first.
    # Clean ES of data before we start.
    @es.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    @es.indices.delete(:index => "*") rescue nil
  end

  context "when action => create" do
    it "should create new documents with or without id" do
      subject = get_es_output("create", "id123")
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
      @es.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @es.search
        insist { r["hits"]["total"] } == 1
      end
    end

    it "should create new documents without id" do
      subject = get_es_output("create")
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
      @es.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @es.search
        insist { r["hits"]["total"] } == 1
      end
    end
  end

  context "when action => create_unless_exists" do
    it "should create new documents when specific id is specified" do
      subject = get_es_output("create_unless_exists", "id123")
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
      @es.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @es.search
        insist { r["hits"]["total"] } == 1
      end
    end

    it "should fail to create a document when no id is specified" do
      event = LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0})
      action = ["create_unless_exists", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event]
      subject = get_es_output(action[0])
      subject.register
      expect { subject.flush([action]) }.to raise_error
    end

    it "should unsuccesfully submit two records with the same document id" do
      subject = get_es_output("create_unless_exists", "id123")
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.receive(LogStash::Event.new("message" => "sample message here")) # 400 status failure (same id)
      subject.buffer_flush(:final => true)
      @es.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @es.search
        insist { r["hits"]["total"] } == 1
      end
    end
  end
end
