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
      "id" => "%{doc_id}"
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
      :body => { :message => 'Test', :counter => 1 }
    )
    @es.indices.refresh
  end

  context "multiple actions include unsupported action" do
    let(:events) {[
      LogStash::Event.new("action_field" => "index", "id" => 1, "message"=> "hello"),
      LogStash::Event.new("action_field" => "update", "id" => 2, "message"=> "hi"),
      LogStash::Event.new("action_field" => "delete", "id" => 3, "message"=> "bye"),
      LogStash::Event.new("action_field" => "unsupported_action", "id" => 4, "message"=> "world!")
    ]}

    it "should reject unsupported doc" do
      subject = get_es_output
      subject.register
      subject.multi_receive(events)
      events.each do | event |
        action = event.get("action_field")
        if action.eql?("index") || action.eql?("update")
          response = @es.get(:index => INDEX, :type => doc_type, :id => event.get("id"), :refresh => true)
          expect(response['_source']['message']).to eq(event.get("message"))
        else
          expect {@es.get(:index => INDEX, :type => doc_type, :id => event.get("id"), :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
        end
      end
    end
  end
end
