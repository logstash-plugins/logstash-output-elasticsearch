require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/common"
require "java"

describe LogStash::Outputs::ElasticSearch::Common do
  let(:including_class) { Class.new { extend LogStash::Outputs::ElasticSearch::Common } }
  let(:event_data) { {} }
  let(:event) { ::LogStash::Event.new(event_data) }

  describe "safe_event_sprintf" do
    context "with valid references" do
      let(:event_data) { { "id" => "hello" } }
      it "includes the value of the field reference" do
        expect(including_class.safe_event_sprintf(event, "%{id}")).to eql("hello")
      end
    end

    context "with invalid references" do
      let(:event_data) { {} }
      it "sets the param value to nil" do
        expect(including_class.safe_event_sprintf(event, "%{id}")).to be_nil
      end
    end
  end
end
