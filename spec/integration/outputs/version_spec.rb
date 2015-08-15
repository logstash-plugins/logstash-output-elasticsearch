require_relative "../../../spec/es_spec_helper"

describe "all actions with external versioning", :integration => true do
  require "logstash/outputs/elasticsearch"
  require "elasticsearch"

  def get_es_output( protocol, action = "index", id = nil, version = nil)
    settings = {
      "manage_template" => true,
      "index" => "logstash-version",
      "template_overwrite" => true,
      "protocol" => protocol,
      "host" => get_host(),
      "port" => get_port(protocol),
      "action" => action
    }
    settings['document_id'] = id unless id.nil?
    settings['version'] = version unless version.nil?
    settings['version_type'] = "external" unless version.nil?
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
      :index => 'logstash-version',
      :type => 'logs',
      :id => "123",
      :verison => "123",
      :version_type => "external",
      :body => { :message => 'Test' }
    )
    @es.indices.refresh
  end

  ["node", "transport", "http"].each do |protocol|
    ["index", "delete", "update"].each do |action|
      context "#{action} action with #{protocol} protocol" do
        it "should failed with the current version" do
          event = LogStash::Event.new("message" => "Updated test")
          action = ["index", {:_id => "123", :version => "123", :version_type => "external", :_index=>"logstash-version", :_type=>"logs"}, event]
          subject = get_es_output(protocol, action, "123", "123")
          subject.register
          expect { subject.flush([action]) }.to raise_error
        end

        it "should update with a newer version" do
          event = LogStash::Event.new("message" => "Updated test")
          action = ["index", {:_id => "123", :version => "124", :version_type => "external", :_index=>"logstash-version", :_type=>"logs"}, event]
          subject = get_es_output(protocol, action, "123", "124")
          subject.register
          expect { subject.flush([action]) }.to raise_error
        end
      end
    end
  end
end
