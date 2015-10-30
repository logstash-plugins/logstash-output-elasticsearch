require "logstash/outputs/elasticsearch"
require_relative "../../../spec/es_spec_helper"

describe "failures in bulk class expected behavior", :integration => true do
  let(:template) { '{"template" : "not important, will be updated by :index"}' }
  let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
  let(:action1) { ["index", {:_id=>nil, :_routing=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event1] }
  let(:event2) { LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0] }, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
  let(:action2) { ["index", {:_id=>nil, :_routing=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event2] }
  let(:invalid_event) { LogStash::Event.new("geoip" => { "location" => "notlatlon" }, "@timestamp" => "2014-11-17T20:37:17.223Z") }
  let(:max_retries) { 3 }

  def mock_actions_with_response(*resp)
    expanded_responses = resp.map do |resp|
      items = resp["statuses"] && resp["statuses"].map do |status|
        {"create" => {"status" => status, "error" => "Error for #{status}"}}
      end

      {
        "errors" => resp["errors"],
        "items" => items
      }
    end

    allow_any_instance_of(LogStash::Outputs::Elasticsearch::HttpClient).to receive(:bulk).and_return(*expanded_responses)
  end

  subject! do
    settings = {
      "manage_template" => true,
      "index" => "logstash-2014.11.17",
      "template_overwrite" => true,
      "hosts" => get_host_port(),
      "retry_max_items" => 10,
      "retry_max_interval" => 1,
      "max_retries" => max_retries
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    # Delete all templates first.
    require "elasticsearch"

    # Clean ES of data before we start.
    @es = get_client
    @es.indices.delete_template(:name => "*")
    @es.indices.delete(:index => "*")
    @es.indices.refresh
  end

  after :each do
    subject.close
  end

  it "should return no errors if all bulk actions are successful" do
    mock_actions_with_response({"errors" => false})
    expect(subject).to receive(:submit).with([action1, action2]).once.and_call_original
    subject.register
    subject.receive(event1)
    subject.receive(event2)
    subject.flush
    sleep(2)
  end

  it "retry exceptions within the submit body" do
    call_count = 0
    subject.register

    expect(subject.client).to receive(:bulk).with(anything).exactly(3).times do
      if (call_count += 1) <= 2
        raise "error first two times"
      else
        {"errors" => false}
      end
    end

    subject.receive(event1)
    subject.flush
  end

  it "should retry actions with response status of 503" do
    mock_actions_with_response({"errors" => true, "statuses" => [200, 200, 503, 503]},
                               {"errors" => true, "statuses" => [200, 503]},
                               {"errors" => false})
    expect(subject).to receive(:submit).with([action1, action1, action1, action2]).ordered.once.and_call_original
    expect(subject).to receive(:submit).with([action1, action2]).ordered.once.and_call_original
    expect(subject).to receive(:submit).with([action2]).ordered.once.and_call_original

    subject.register
    subject.receive(event1)
    subject.receive(event1)
    subject.receive(event1)
    subject.receive(event2)
    subject.flush
    sleep(3)
  end

  it "should retry actions with response status of 429" do
    subject.register

    mock_actions_with_response({"errors" => true, "statuses" => [429]},
                               {"errors" => false})
    expect(subject).to receive(:submit).with([action1]).twice.and_call_original

    subject.receive(event1)
    subject.flush
    sleep(3)
  end

  it "should retry an event until max_retries reached" do
    mock_actions_with_response({"errors" => true, "statuses" => [429]},
                               {"errors" => true, "statuses" => [429]},
                               {"errors" => true, "statuses" => [429]},
                               {"errors" => true, "statuses" => [429]},
                               {"errors" => true, "statuses" => [429]},
                               {"errors" => true, "statuses" => [429]})
    expect(subject).to receive(:submit).with([action1]).exactly(max_retries+1).times.and_call_original
    subject.register
    subject.receive(event1)
    subject.flush
    sleep(5)
  end

  it "non-retryable errors like mapping errors (400) should be dropped and not be retried (unfortunately)" do
    subject.register
    subject.receive(invalid_event)
    expect(subject).not_to receive(:retry_push)
    subject.close

    @es.indices.refresh
    sleep(5)
    Stud::try(10.times) do
      r = @es.search
      insist { r["hits"]["total"] } == 0
    end
  end

  it "successful requests should not be appended to retry queue" do
    subject.register
    subject.receive(event1)
    expect(subject).not_to receive(:retry_push)
    subject.close
    @es.indices.refresh
    sleep(5)
    Stud::try(10.times) do
      r = @es.search
      insist { r["hits"]["total"] } == 1
    end
  end

  it "should only index proper events" do
    subject.register
    subject.receive(invalid_event)
    subject.receive(event1)
    subject.close

    @es.indices.refresh
    sleep(5)
    Stud::try(10.times) do
      r = @es.search
      insist { r["hits"]["total"] } == 1
    end
  end
end
