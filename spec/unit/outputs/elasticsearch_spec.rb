require_relative "../../../spec/es_spec_helper"
require "flores/random"

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

  describe "http client create" do
    require "logstash/outputs/elasticsearch"
    require "elasticsearch"

    let(:options) {
      {
        "protocol" => "http",
        "index" => "my-index",
        "host" => "localhost",
        "path" => "some-path"
      }
    }

    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}

    let(:manticore_host) {
      eso.client.first.send(:client).transport.options[:host].first
    }

    around(:each) do |block|
      thread = eso.register
      block.call()
      thread.kill()
    end

    describe "with path" do
      it "should properly create a URI with the path" do
        expect(eso.path).to eql(options["path"])
      end


      it "should properly set the path on the HTTP client adding slashes" do
        expect(manticore_host).to include("/" + options["path"] + "/")
      end

      context "with extra slashes" do
        let(:path) { "/slashed-path/ "}
        let(:eso) {
          LogStash::Outputs::ElasticSearch.new(options.merge("path" => "/some-path/"))
        }

        it "should properly set the path on the HTTP client without adding slashes" do
          expect(manticore_host).to include(options["path"])
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


  # TODO(sissel): Improve this. I'm not a fan of using message expectations (expect().to receive...)
  # especially with respect to logging to verify a failure/retry has occurred. For now, this 
  # should suffice, though.
  context "with timeout set" do
    let(:listener) { Flores::Random.tcp_listener }
    let(:port) { listener[2] }
    let(:options) do
      {
        "protocol" => "http",
        "manage_template" => false,
        "host" => "localhost",
        "port" => port,
        "flush_size" => 1,
        "timeout" => 1,
      }
    end
    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}
    
    before do
      eso.logger = Cabin::Channel.get
      eso.register 

      # Expect a timeout to be logged.
      expect(eso.logger).to receive(:warn).with("Failed to flush outgoing items",
                                                hash_including(:exception => "Manticore::SocketTimeout"))
    end

    after do
      listener[0].close
      eso.close
    end

    it "should fail after the timeout" do
      Thread.new { eso.receive(LogStash::Event.new) }

      # Allow the timeout to occur.
      sleep(options["timeout"] + 0.5)
    end
  end
end
