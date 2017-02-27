require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"

describe LogStash::Outputs::ElasticSearch::HttpClient do
  let(:ssl) { nil }
  let(:base_options) do
    opts = {
      :hosts => [::LogStash::Util::SafeURI.new("127.0.0.1")],
      :logger => Cabin::Channel.get
    }

    if !ssl.nil? # Shortcut to set this
      opts[:client_settings] = {:ssl => {:enabled => ssl}}
    end

    opts
  end

  describe "Host/URL Parsing" do
    subject { described_class.new(base_options) }

    let(:true_hostname) { "my-dash.hostname" }
    let(:ipv6_hostname) { "[::1]" }
    let(:ipv4_hostname) { "127.0.0.1" }
    let(:port) { 9202 }
    let(:hostname_port) { "#{hostname}:#{port}" }
    let(:hostname_port_uri) { ::LogStash::Util::SafeURI.new("//#{hostname_port}") }
    let(:http_hostname_port) { ::LogStash::Util::SafeURI.new("http://#{hostname_port}") }
    let(:https_hostname_port) { ::LogStash::Util::SafeURI.new("https://#{hostname_port}") }
    let(:http_hostname_port_path) { ::LogStash::Util::SafeURI.new("http://#{hostname_port}/path") }
    
    shared_examples("proper host handling") do
      it "should properly transform a host:port string to a URL" do
        expect(subject.host_to_url(hostname_port_uri)).to eq(http_hostname_port)
      end

      it "should not raise an error with a / for a path" do
        expect(subject.host_to_url(::LogStash::Util::SafeURI.new("#{http_hostname_port}/"))).to eq(LogStash::Util::SafeURI.new("#{http_hostname_port}/"))
      end

      it "should parse full URLs correctly" do
        expect(subject.host_to_url(http_hostname_port)).to eq(http_hostname_port)
      end

      describe "ssl" do
        context "when SSL is true" do
          let(:ssl) { true }
          let(:base_options) { super.merge(:hosts => [http_hostname_port]) }

          it "should refuse to handle an http url" do
            expect {
              subject.host_to_url(http_hostname_port)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end

        context "when SSL is false" do
          let(:ssl) { false }
          let(:base_options) { super.merge(:hosts => [https_hostname_port]) }
          
          it "should refuse to handle an https url" do
            expect {
              subject.host_to_url(https_hostname_port)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end

        describe "ssl is nil" do
          let(:base_options) { super.merge(:hosts => [https_hostname_port]) }
          it "should handle an ssl url correctly when SSL is nil" do
            subject
            expect(subject.host_to_url(https_hostname_port)).to eq(https_hostname_port)
          end
        end       
      end

      describe "path" do
        let(:url) { http_hostname_port_path }
        let(:base_options) { super.merge(:hosts => [url]) }
        
        it "should allow paths in a url" do
          expect(subject.host_to_url(url)).to eq(url)
        end

        context "with the path option set" do
          let(:base_options) { super.merge(:client_settings => {:path => "/otherpath"}) }
          
          it "should not allow paths in two places" do
            expect {
              subject.host_to_url(url)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end
        
        context "with a path missing a leading /" do
          let(:url) { http_hostname_port }
          let(:base_options) { super.merge(:client_settings => {:path => "otherpath"}) }
          
          
          it "should automatically insert a / in front of path overlays" do
            expect(subject.host_to_url(url)).to eq(LogStash::Util::SafeURI.new(url + "/otherpath"))
          end
        end
      end
    end

    describe "an regular hostname" do
      let(:hostname) { true_hostname }
      include_examples("proper host handling")
    end

    describe "an ipv4 host" do
      let(:hostname) { ipv4_hostname }
      include_examples("proper host handling")
    end

    describe "an ipv6 host" do
      let(:hostname) { ipv6_hostname }
      include_examples("proper host handling")
    end
  end

  describe "get" do
    subject { described_class.new(base_options) }
    let(:body) { "foobar" }
    let(:path) { "/hello-id" }
    let(:get_response) {
      double("response", :body => LogStash::Json::dump( { "body" => body }))
    }

    it "returns the hash response" do
      expect(subject.pool).to receive(:get).with(path, nil).and_return([nil, get_response])
      expect(subject.get(path)["body"]).to eq(body)
    end
  end

  describe "join_bulk_responses" do
    subject { described_class.new(base_options) }

    context "when items key is available" do
      require "json"
      let(:bulk_response) {
        LogStash::Json.load ('[{
          "items": [{
            "delete": {
              "_index":   "website",
              "_type":    "blog",
              "_id":      "123",
              "_version": 2,
              "status":   200,
              "found":    true
            }
          }],
          "errors": false
        }]')
      }
      it "should be handled properly" do
        s = subject.send(:join_bulk_responses, bulk_response)
        expect(s["errors"]).to be false
        expect(s["items"].size).to be 1
      end
    end

    context "when items key is not available" do
      require "json"
      let(:bulk_response) {
        JSON.parse ('[{
          "took": 4,
          "errors": false
        }]')
      }
      it "should be handled properly" do
        s = subject.send(:join_bulk_responses, bulk_response)
        expect(s["errors"]).to be false
        expect(s["items"].size).to be 0
      end
    end
  end

  describe "sniffing" do
    let(:client) { LogStash::Outputs::ElasticSearch::HttpClient.new(base_options.merge(client_opts)) }

    context "with sniffing enabled" do
      let(:client_opts) { {:sniffing => true, :sniffing_delay => 1 } }

      it "should start the sniffer" do
        expect(client.pool.sniffing).to be_truthy
      end
    end

    context "with sniffing disabled" do
      let(:client_opts) { {:sniffing => false} }

      it "should not start the sniffer" do
        expect(client.pool.sniffing).to be_falsey
      end
    end
  end
end
