require_relative "../../../spec/es_spec_helper"

describe "client create actions", :integration => true do
  require "logstash/outputs/elasticsearch"
  require "elasticsearch"

  def get_es_output(action, id = nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-create",
      "template_overwrite" => true,
      "hosts" => get_host(),
      "port" => get_port(),
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
end
