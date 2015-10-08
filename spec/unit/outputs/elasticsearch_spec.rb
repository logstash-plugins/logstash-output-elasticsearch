require_relative "../../../spec/es_spec_helper"

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
end
