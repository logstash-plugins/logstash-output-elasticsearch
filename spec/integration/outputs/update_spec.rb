require_relative "../../../spec/es_spec_helper"

describe "Update action", :integration => true do
  require "logstash/outputs/elasticsearch"
  require "elasticsearch"

  def get_es_output( options={} )
    settings = {
      "manage_template" => true,
      "index" => "logstash-update",
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "action" => "update"
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
    event = LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0})
    action = ["update", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event]
    subject = get_es_output
    subject.register
    expect { subject.flush([action]) }.to raise_error
  end

  it "should not create new document" do
    subject = get_es_output({ 'document_id' => "456" } )
    subject.register
    subject.receive(LogStash::Event.new("message" => "sample message here"))
    subject.flush
    expect {@es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
  end

  it "should update existing document" do
    subject = get_es_output({ 'document_id' => "123" })
    subject.register
    subject.receive(LogStash::Event.new("message" => "updated message here"))
    subject.flush
    r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
    insist { r["_source"]["message"] } == 'updated message here'
  end

  context "upsert" do
    it "should create new documents with upsert content" do
      subject = get_es_output({ 'document_id' => "456", 'upsert' => '{"message": "upsert message"}' })
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.flush
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["message"] } == 'upsert message'
    end

    it "should create new documents with event/doc as upsert" do
      subject = get_es_output({ 'document_id' => "456", 'doc_as_upsert' => true })
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.flush
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["message"] } == 'sample message here'
    end
  end

  context "scripted update" do

    it "should create new documents with upsert content" do
      subject = get_es_output({ 'document_id' => "456", 'script' => 'scripted_update', 'upsert' => '{"message": "upsert message"}' })
      subject.register
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["message"] } == 'upsert message'
    end

    it "should create new documents with event/doc as script params" do
      subject = get_es_output({ 'document_id' => "456", 'script' => 'scripted_upsert', 'scripted_upsert' => true })
      subject.register
      subject.receive(LogStash::Event.new("counter" => 1))
      subject.buffer_flush(:final => true)
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
      insist { r["_source"]["counter"] } == 1
    end

    it "should increment a counter with event/doc 'count' variable" do
      subject = get_es_output({ 'document_id' => "123", 'script' => 'scripted_update' })
      subject.register
      subject.receive(LogStash::Event.new("count" => 2))
      subject.buffer_flush(:final => true)
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 3
    end

    it "should increment a counter with event/doc '[data][count]' nested variable" do
      subject = get_es_output({ 'document_id' => "123", 'script' => 'scripted_update_nested' })
      subject.register
      subject.receive(LogStash::Event.new("data" => { "count" => 3 }))
      subject.buffer_flush(:final => true)
      r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
      insist { r["_source"]["counter"] } == 4
    end

    it "should raise a configuration error" do
      subject = get_es_output({ 'document_id' => "123", 'script' => 'scripted_update' })
      expect { subject.register }.to raise_error
    end

  end
end
