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
    params_index = generate_common_index_params(INDEX, '2')
    params_index[:body] = { :message => 'Test to doc indexing', :counter => 1 }
    @es.index(params_index)

    params_delete = generate_common_index_params(INDEX, '3')
    params_delete[:body] = { :message => 'Test to doc deletion', :counter => 2 }
    @es.index(params_delete)
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

      indexed_events = events.select { |event| index_or_update.call(event) }
      rejected_events = events.select { |event| !index_or_update.call(event) }

      indexed_events.each do |event|
        response = @es.get(generate_common_index_params(INDEX, event.get("doc_id")))
        expect(response['_source']['message']).to eq(event.get("message"))
      end

      rejected_events.each do |event|
        expect {@es.get(generate_common_index_params(INDEX, event.get("doc_id")))}.to raise_error(get_expected_error_class)
      end
    end
  end
end
