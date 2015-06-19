require_relative "../../../spec/es_spec_helper"

describe "outputs/elasticsearch" do
  context "registration" do
    it "should register" do
      output = LogStash::Plugin.lookup("output", "elasticsearch").new("embedded" => "false", "protocol" => "transport", "manage_template" => "false")
      # register will try to load jars and raise if it cannot find jars
      expect {output.register}.to_not raise_error
    end

    it "should fail to register when protocol => http, action => create_unless_exists" do
      output = LogStash::Plugin.lookup("output", "elasticsearch").new("protocol" => "http", "action" => "create_unless_exists")
      expect {output.register}.to raise_error
    end
  end

  describe "Authentication option" do
    ["node", "transport"].each do |protocol|
      context "with protocol => #{protocol}" do
        subject do
          require "logstash/outputs/elasticsearch"
          settings = {
            "protocol" => protocol,
            "node_name" => "logstash",
            "cluster" => "elasticsearch",
            "host" => "node01",
            "user" => "test",
            "password" => "test"
          }
          next LogStash::Outputs::ElasticSearch.new(settings)
        end

        it "should fail in register" do
          expect {subject.register}.to raise_error
        end
      end
    end
  end

  describe "transport protocol" do
    context "host not configured" do
      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "protocol" => "transport",
          "node_name" => "mynode"
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should set host to localhost" do
        expect(LogStash::Outputs::Elasticsearch::Protocols::TransportClient).to receive(:new).with({
          :host => "localhost",
          :port => "9300-9305",
          :protocol => "transport",
          :client_settings => {
            "client.transport.sniff" => false,
            "node.name" => "mynode"
          }
        })
        subject.register
      end
    end

    context "sniffing => true" do
      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "host" => "node01",
          "protocol" => "transport",
          "sniffing" => true
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should set the sniffing property to true" do
        expect_any_instance_of(LogStash::Outputs::Elasticsearch::Protocols::TransportClient).to receive(:client).and_return(nil)
        subject.register
        client = subject.instance_eval("@current_client")
        settings = client.instance_eval("@settings")

        expect(settings.build.getAsMap["client.transport.sniff"]).to eq("true")
      end
    end

    context "sniffing => false" do
      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "host" => "node01",
          "protocol" => "transport",
          "sniffing" => false
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should set the sniffing property to true" do
        expect_any_instance_of(LogStash::Outputs::Elasticsearch::Protocols::TransportClient).to receive(:client).and_return(nil)
        subject.register
        client = subject.instance_eval("@current_client")
        settings = client.instance_eval("@settings")

        expect(settings.build.getAsMap["client.transport.sniff"]).to eq("false")
      end
    end
  end
end
