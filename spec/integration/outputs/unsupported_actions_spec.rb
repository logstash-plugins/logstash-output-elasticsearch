require_relative "../../../spec/es_spec_helper"

describe "Unsupported actions testing...", :integration => true do
  require "logstash/outputs/elasticsearch"

  INDEX = "logstash-unsupported-actions-rejected"

  def get_es_output( options={} )
    settings = {
      "manage_template" => true,
      "index" => INDEX,
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "action" => "%{action_field}",
      "document_id" => "%{doc_id}",
      "ecs_compatibility" => "disabled"
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
    # index single doc for update purpose
    @es.index(
      :index => INDEX,
      :type => doc_type,
      :id => "2",
      :body => { :message => 'Test to doc indexing', :counter => 1 }
    )
    @es.index(
      :index => INDEX,
      :type => doc_type,
      :id => "3",
      :body => { :message => 'Test to doc deletion', :counter => 2 }
    )
    @es.indices.refresh
  end

  context "multiple actions include unsupported action" do
    let(:events) {[
      LogStash::Event.new("action_field" => "index", "doc_id" => 1, "message"=> "hello"),
      LogStash::Event.new("action_field" => "update", "doc_id" => 2, "message"=> "hi"),
      LogStash::Event.new("action_field" => "delete", "doc_id" => 3),
      LogStash::Event.new("action_field" => "unsupported_action", "doc_id" => 4, "message"=> "world!")
    ]}

    it "should reject unsupported doc" do
      subject = get_es_output
      subject.register
      subject.multi_receive(events)

      index_or_update = proc do |event|
        action = event.get("action_field")
        action.eql?("index") || action.eql?("update")
      end

      indexed_events = events.filter { |event| index_or_update.call(event) }
      rejected_events = events.filter { |event| !index_or_update.call(event) }

      indexed_events.each do |event|
        response = @es.get(:index => INDEX, :type => doc_type, :id => event.get("doc_id"), :refresh => true)
        expect(response['_source']['message']).to eq(event.get("message"))
      end

      rejected_events.each do |event|
        expect {@es.get(:index => INDEX, :type => doc_type, :id => event.get("doc_id"), :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      end
    end
  end
end
