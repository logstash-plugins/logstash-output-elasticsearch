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
    LogStash::Outputs::Elasticsearch::Protocols::HTTPClient
      .any_instance.stub(:bulk).and_return(*resp)
    LogStash::Outputs::Elasticsearch::Protocols::NodeClient
      .any_instance.stub(:bulk).and_return(*resp)
  end

  ["transport", "http"].each do |protocol|
    context "with protocol => #{protocol}" do
      subject! do
        settings = {
          "manage_template" => true,
          "index" => "logstash-2014.11.17",
          "template_overwrite" => true,
          "protocol" => protocol,
          "host" => get_host(),
          "port" => get_port(protocol),
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

      it "should return no errors if all bulk actions are successful" do
        mock_actions_with_response({"errors" => false})
        expect(subject).to receive(:submit).with([action1, action2]).once.and_call_original
        subject.register
        subject.receive(event1)
        subject.receive(event2)
        subject.buffer_flush(:final => true)
        sleep(2)
      end

      it "should raise exception and be retried by stud::buffer" do
        call_count = 0
        expect(subject).to receive(:submit).with([action1]).exactly(3).times do
          if (call_count += 1) <= 2
            raise "error first two times"
          else
            {"errors" => false}
          end
        end
        subject.register
        subject.receive(event1)
        subject.teardown
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
        subject.buffer_flush(:final => true)
        sleep(3)
      end

      it "should retry actions with response status of 429" do
        mock_actions_with_response({"errors" => true, "statuses" => [429]},
                                   {"errors" => false})
        expect(subject).to receive(:submit).with([action1]).twice.and_call_original
        subject.register
        subject.receive(event1)
        subject.buffer_flush(:final => true)
        sleep(3)
      end

      it "should retry an event until max_retries reached" do
        mock_actions_with_response({"errors" => true, "statuses" => [429]},
                                   {"errors" => true, "statuses" => [429]},
                                   {"errors" => true, "statuses" => [429]},
                                   {"errors" => true, "statuses" => [429]},
                                   {"errors" => true, "statuses" => [429]},
                                   {"errors" => true, "statuses" => [429]})
        expect(subject).to receive(:submit).with([action1]).exactly(max_retries).times.and_call_original
        subject.register
        subject.receive(event1)
        subject.buffer_flush(:final => true)
        sleep(3)
      end

      it "non-retryable errors like mapping errors (400) should be dropped and not be retried (unfortunetly)" do
        subject.register
        subject.receive(invalid_event)
        expect(subject).not_to receive(:retry_push)
        subject.teardown

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
        subject.teardown

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
        subject.teardown

        @es.indices.refresh
        sleep(5)
        Stud::try(10.times) do
          r = @es.search
          insist { r["hits"]["total"] } == 1
        end
      end
    end
  end
end
