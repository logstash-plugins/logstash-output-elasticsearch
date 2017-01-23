require_relative "../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch"


describe "Versioned delete", :integration => true, :version_greater_than_equal_to_2x => true do
  require "logstash/outputs/elasticsearch"

  before :each do
    send_delete_all
  end

  context "when delete only" do
    subject { LogStash::Outputs::ElasticSearch.new(settings) }

    before do
      subject.register
    end

    let(:settings) do
      {
        "manage_template" => true,
        "index" => "logstash-delete",
        "template_overwrite" => true,
        "hosts" => get_host_port(),
        "document_id" => "%{my_id}",
        "version" => "%{my_version}",
        "version_type" => "external",
        "action" => "%{my_action}"
      }
    end

    it "should ignore non-monotonic external version updates" do
      id = "ev2"
      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "index", "message" => "foo", "my_version" => 99)])
      r = send_json_request(:get, "/logstash-delete/logs/#{id}")
      expect(r['_version']).to eq(99)
      expect(r['_source']['message']).to eq('foo')

      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "delete", "message" => "foo", "my_version" => 98)])
      r2 = send_json_request(:get, "/logstash-delete/logs/#{id}")
      expect(r2['_version']).to eq(99)
      expect(r2['_source']['message']).to eq('foo')
    end

    it "should commit monotonic external version updates" do
      id = "ev3"
      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "index", "message" => "foo", "my_version" => 99)])
      r = send_json_request(:get, "/logstash-delete/logs/#{id}")
      expect(r['_version']).to eq(99)
      expect(r['_source']['message']).to eq('foo')

      subject.multi_receive([LogStash::Event.new("my_id" => id, "my_action" => "delete", "message" => "foo", "my_version" => 100)])
      expect(send_request(:get, "/logstash-delete/logs/#{id}").code).to eq(404)
    end
  end
end
