require_relative "../../../spec/es_spec_helper"

describe "client create actions", :integration => true do
  require "logstash/outputs/elasticsearch"

  def get_es_output(action, id, version=nil, version_type=nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-create",
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "action" => action
    }
    settings['document_id'] = id
    settings['version'] = version if version
    settings['version_type'] = version_type if version_type
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
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
      @es.indices.refresh
      # Wait or fail until everything's indexed.
      Stud::try(3.times) do
        r = @es.search
        expect(r).to have_hits(1)
      end
    end

    it "should allow default (internal) version" do
      subject = get_es_output("create", "id123", 43)
      subject.register
    end

    it "should allow internal version" do
      subject = get_es_output("create", "id123", 43, "internal")
      subject.register
    end

    it "should not allow external version" do
      subject = get_es_output("create", "id123", 43, "external")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gt version" do
      subject = get_es_output("create", "id123", 43, "external_gt")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gte version" do
      subject = get_es_output("create", "id123", 43, "external_gte")
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end
  end
end
