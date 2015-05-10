require_relative "../../../spec/es_spec_helper"

describe "all protocols update actions", :integration => true do
  require "logstash/outputs/elasticsearch"
  require "elasticsearch"

  def get_es_output( protocol, id = nil, upsert = nil, doc_as_upsert=nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-update",
      "template_overwrite" => true,
      "protocol" => protocol,
      "host" => get_host(),
      "port" => get_port(protocol),
      "action" => "update"
    }
    settings['upsert'] = upsert unless upsert.nil?
    settings['document_id'] = id unless id.nil?
    settings['doc_as_upsert'] = doc_as_upsert unless doc_as_upsert.nil?
    LogStash::Outputs::ElasticSearch.new(settings)
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
      :body => { :message => 'Test' }
    )
    @es.indices.refresh
  end

  ["node", "transport", "http"].each do |protocol|
    context "update only with #{protocol} protocol" do
      it "should failed without a document_id" do
        event = LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0})
        action = ["update", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event]
        subject = get_es_output(protocol)
        subject.register
        expect { subject.flush([action]) }.to raise_error
      end

      it "should not create new document" do
        subject = get_es_output(protocol, "456")
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        expect {@es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      end

      it "should update existing document" do
        subject = get_es_output(protocol, "123")
        subject.register
        subject.receive(LogStash::Event.new("message" => "updated message here"))
        subject.buffer_flush(:final => true)
        r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "123", :refresh => true)
        insist { r["_source"]["message"] } == 'updated message here'
      end
    end

    context "upsert with #{protocol} protocol" do
      it "should create new documents with upsert content" do
        subject = get_es_output(protocol, "456", '{"message": "upsert message"}')
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
        insist { r["_source"]["message"] } == 'upsert message'
      end

      it "should create new documents with event/doc as upsert" do
        subject = get_es_output(protocol, "456", nil, true)
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        r = @es.get(:index => 'logstash-update', :type => 'logs', :id => "456", :refresh => true)
        insist { r["_source"]["message"] } == 'sample message here'
      end
    end
  end
end
