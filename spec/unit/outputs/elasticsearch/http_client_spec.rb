require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "java"

describe LogStash::Outputs::ElasticSearch::HttpClient do
  let(:base_options) { {:hosts => ["127.0.0.1"], :logger => Cabin::Channel.get }}

  describe "Host/URL Parsing" do
    subject { described_class.new(base_options) }

    let(:true_hostname) { "my-dash.hostname" }
    let(:ipv6_hostname) { "[::1]" }
    let(:ipv4_hostname) { "127.0.0.1" }
    let(:port) { 9202 }
    let(:hostname_port) { "#{hostname}:#{port}"}
    let(:http_hostname_port) { "http://#{hostname_port}"}
    let(:https_hostname_port) { "https://#{hostname_port}"}
    let(:http_hostname_port_path) { "http://#{hostname_port}/path"}

    shared_examples("proper host handling") do
      it "should properly transform a host:port string to a URL" do
        expect(subject.send(:host_to_url, hostname_port).to_s).to eql(http_hostname_port)
      end

      it "should raise an error when a partial URL is an invalid format" do
        expect {
          subject.send(:host_to_url, "#{hostname_port}/")
        }.to raise_error(LogStash::ConfigurationError)
      end

      it "should not raise an error with a / for a path" do
        expect(subject.send(:host_to_url, "#{http_hostname_port}/").to_s).to eql("#{http_hostname_port}/")
      end

      it "should parse full URLs correctly" do
        expect(subject.send(:host_to_url, http_hostname_port).to_s).to eql(http_hostname_port)
      end

      it "should reject full URLs with usernames and passwords" do
        expect {
          subject.send(:host_to_url, "http://user:password@host.domain")
        }.to raise_error(LogStash::ConfigurationError)
      end

      describe "ssl" do
        it "should refuse to handle an http url when ssl is true" do
          expect {
            subject.send(:host_to_url, http_hostname_port, true)
          }.to raise_error(LogStash::ConfigurationError)
        end

        it "should refuse to handle an https url when ssl is false" do
          expect {
            subject.send(:host_to_url, https_hostname_port, false)
          }.to raise_error(LogStash::ConfigurationError)
        end

        it "should handle an ssl url correctly when SSL is nil" do
          expect(subject.send(:host_to_url, https_hostname_port, nil).to_s).to eql(https_hostname_port)
        end

        it "should raise an exception if an unexpected value is passed in" do
          expect { subject.send(:host_to_url, https_hostname_port, {})}.to raise_error(ArgumentError)
        end
      end

      describe "path" do
        it "should allow paths in a url" do
          expect(subject.send(:host_to_url, http_hostname_port_path, nil).to_s).to eql(http_hostname_port_path)
        end

        it "should not allow paths in two places" do
          expect {
            subject.send(:host_to_url, http_hostname_port_path, false, "/otherpath")
          }.to raise_error(LogStash::ConfigurationError)
        end

        it "should automatically insert a / in front of path overlays if needed" do
          expect(subject.send(:host_to_url, http_hostname_port, false, "otherpath")).to eql(URI.parse(http_hostname_port + "/otherpath"))
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
