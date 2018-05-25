require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"
require "logstash/outputs/elasticsearch/helpers"

describe LogStash::Outputs::ElasticSearch::Helpers do
  context "detecting if an index name can be determined for an event" do
    let(:event_with_ts) { LogStash::Event.new() }
    let(:event_with_no_ts) { LogStash::Event.new().tap { |e| e.remove('@timestamp') } }

    context "when the index pattern doesn't include a timestamp" do
      ['my-index', 'logstash-%{normal_field_interpolation}'].each do |index|
        context "where index = #{index.inspect}" do
          it "should detect no problems for events that have a timestamp" do
            expect(subject.predict_timestamp_issue_for(index, event_with_ts)).to eq(false)
          end

          it "should detect no problems for events that do not have a timestamp" do
            expect(subject.predict_timestamp_issue_for(index, event_with_no_ts)).to eq(false)
          end
        end
      end
    end

    context "when the index pattern includes a timestamp" do
      ['logstash-%{+YYYY.MM.dd}', 'logstash-%{+YYYY}', '%{+YYYY.MM.dd}-what'].each do |index|
        context "where index = #{index.inspect}" do
          it "should detect no problems for events that have a timestamp" do
            expect(subject.predict_timestamp_issue_for(index, event_with_ts)).to eq(false)
          end

          it "should detect a problem for events that do not have a timestamp" do
            expect(subject.predict_timestamp_issue_for(index, event_with_no_ts)).to eq(true)
          end
        end
      end
    end

  end
end
