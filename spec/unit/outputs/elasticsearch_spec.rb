require_relative "../../../spec/es_spec_helper"
require "flores/random"

describe "outputs/elasticsearch" do
  describe "http client create" do
    require "logstash/outputs/elasticsearch"
    require "elasticsearch"

    let(:options) {
      {
        "index" => "my-index",
        "hosts" => ["localhost","localhost:9202"],
        "path" => "some-path"
      }
    }

    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}

    let(:manticore_host) {
      eso.client.send(:client).transport.options[:hosts].first
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
    describe "without a port specified" do
      it "should properly set the default port (9200) on the HTTP client" do
        expect(manticore_host).to include("9200")
      end
    end
    describe "with a port other than 9200 specified" do
      let(:manticore_host) {
        eso.client.send(:client).transport.options[:hosts].last
      }
      it "should properly set the specified port on the HTTP client" do
        expect(manticore_host).to include("9202")
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
        "manage_template" => false,
        "hosts" => "localhost:#{port}",
        "flush_size" => 1,
        "timeout" => 0.1, # fast timeout
      }
    end
    let(:eso) {LogStash::Outputs::ElasticSearch.new(options)}
    
    before do
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
      sleep(options["timeout"] + 0.3)
    end
  end
end
