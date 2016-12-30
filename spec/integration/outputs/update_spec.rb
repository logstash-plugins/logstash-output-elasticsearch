require_relative "../../../spec/es_spec_helper"

describe "Update actions", :integration => true, :version_greater_than_equal_to_2x => true do
  require "logstash/outputs/elasticsearch"

  def get_es_output( options={} )
    settings = {
      "manage_template" => true,
      "index" => "logstash-update",
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "action" => "update",
      "script_lang" => "groovy"
    }
    LogStash::Outputs::ElasticSearch.new(settings.merge!(options))
  end

  before :each do
    @es = get_client
    # Delete all templates first.
    # Clean ES of data before we start.
    @es.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    @es.indices.delete(:index => "*") rescue nil
    @es.index(
      :index => 'logstash-update',
      :type => 'logs',
      :id => "123",
      :body => { :message => 'Test', :counter => 1 }
    )
    @es.indices.refresh
  end

  it "should fail without a document_id" do
    subject = get_es_output
    expect { subject.register }.to raise_error(LogStash::ConfigurationError)
  end

  context "when update only" do
    it "should not create new document" do
      subject = get_es_output({ 'document_id' => "456" } )
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
      expect {@es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end

    it "should update existing document" do
      subject = get_es_output({ 'document_id' => "123" })
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "updated message here")])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["message"] } == 'updated message here'
    end

    # The es ruby client treats the data field differently. Make sure this doesn't
    # raise an exception
    it "should update an existing document that has a 'data' field" do
      subject = get_es_output({ 'document_id' => "123" })
      subject.register
      subject.multi_receive([LogStash::Event.new("data" => "updated message here", "message" => "foo")])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["data"] } == 'updated message here'
      insist { r["_source"]["message"] } == 'foo'
    end

    it "should allow default (internal) version" do
      subject = get_es_output({ 'document_id' => "123", "version" => "99" })
      subject.register
    end

    it "should allow internal version" do
      subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "internal" })
      subject.register
    end

    it "should not allow external version" do
      subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external" })
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gt version" do
      subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external_gt" })
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    it "should not allow external_gte version" do
      subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external_gte" })
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

  end

  context "when using script" do
    it "should increment a counter with event/doc 'count' variable" do
      subject = get_es_output({ 'document_id' => "123", 'script' => 'scripted_update', 'script_type' => 'file' })
      subject.register
      subject.multi_receive([LogStash::Event.new("count" => 2)])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 3
    end

    it "should increment a counter with event/doc '[data][count]' nested variable" do
      subject = get_es_output({ 'document_id' => "123", 'script' => 'scripted_update_nested', 'script_type' => 'file' })
      subject.register
      subject.multi_receive([LogStash::Event.new("data" => { "count" => 3 })])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 4
    end

    it "should increment a counter with event/doc 'count' variable with inline script" do
      subject = get_es_output({
        'document_id' => "123",
        'script' => 'ctx._source.counter += event["counter"]',
        'script_lang' => 'groovy',
        'script_type' => 'inline'
      })
      subject.register
      subject.multi_receive([LogStash::Event.new("counter" => 3 )])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 4
    end

    it "should increment a counter with event/doc 'count' variable with event/doc as upsert and inline script" do
      subject = get_es_output({
        'document_id' => "123",
        'doc_as_upsert' => true,
        'script' => 'if( ctx._source.containsKey("counter") ){ ctx._source.counter += event["counter"]; } else { ctx._source.counter = event["counter"]; }',
        'script_lang' => 'groovy',
        'script_type' => 'inline'
      })
      subject.register
      subject.multi_receive([LogStash::Event.new("counter" => 3 )])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 4
    end

    it "should, with new doc, set a counter with event/doc 'count' variable with event/doc as upsert and inline script" do
      subject = get_es_output({
        'document_id' => "456",
        'doc_as_upsert' => true,
        'script' => 'if( ctx._source.containsKey("counter") ){ ctx._source.counter += event["count"]; } else { ctx._source.counter = event["count"]; }',
        'script_lang' => 'groovy',
        'script_type' => 'inline'
      })
      subject.register
      subject.multi_receive([LogStash::Event.new("counter" => 3 )])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["counter"] } == 3
    end

    it "should increment a counter with event/doc 'count' variable with indexed script" do
      @es.put_script lang: 'groovy', id: 'indexed_update', body: { script: 'ctx._source.counter += event["count"]' }
      subject = get_es_output({
        'document_id' => "123",
        'script' => 'indexed_update',
        'script_lang' => 'groovy',
        'script_type' => 'indexed'
      })
      subject.register
      subject.multi_receive([LogStash::Event.new("count" => 4 )])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 5
    end
  end

  context "when update with upsert" do
    it "should create new documents with provided upsert" do
      subject = get_es_output({ 'document_id' => "456", 'upsert' => '{"message": "upsert message"}' })
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["message"] } == 'upsert message'
    end

    it "should create new documents with event/doc as upsert" do
      subject = get_es_output({ 'document_id' => "456", 'doc_as_upsert' => true })
      subject.register
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["message"] } == 'sample message here'
    end

    it "should fail on documents with event/doc as upsert at external version" do
      subject = get_es_output({ 'document_id' => "456", 'doc_as_upsert' => true, 'version' => 999, "version_type" => "external" })
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    context "when using script" do
      it "should create new documents with upsert content" do
        subject = get_es_output({ 'document_id' => "456", 'script' => 'scripted_update', 'upsert' => '{"message": "upsert message"}', 'script_type' => 'file' })
        subject.register
        subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
        r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
        insist { r["_source"]["message"] } == 'upsert message'
      end

      it "should create new documents with event/doc as script params" do
        subject = get_es_output({ 'document_id' => "456", 'script' => 'scripted_upsert', 'scripted_upsert' => true, 'script_type' => 'file' })
        subject.register
        subject.multi_receive([LogStash::Event.new("counter" => 1)])
        @es.indices.refresh
        r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
        insist { r["_source"]["counter"] } == 1
      end
    end
  end
end
