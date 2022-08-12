require_relative "../../../../spec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "cabin"
require "webrick"
require "java"

describe LogStash::Outputs::ElasticSearch::HttpClient do
  let(:ssl) { nil }
  let(:base_options) do
    opts = {
      :hosts => [::LogStash::Util::SafeURI.new("127.0.0.1")],
      :logger => Cabin::Channel.get,
      :metric => ::LogStash::Instrument::NullMetric.new(:dummy).namespace(:alsodummy)
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
        expect(subject.host_to_url(hostname_port_uri).to_s).to eq(http_hostname_port.to_s + "/")
      end

      it "should not raise an error with a / for a path" do
        expect(subject.host_to_url(::LogStash::Util::SafeURI.new("#{http_hostname_port}/"))).to eq(LogStash::Util::SafeURI.new("#{http_hostname_port}/"))
      end

      it "should parse full URLs correctly" do
        expect(subject.host_to_url(http_hostname_port).to_s).to eq(http_hostname_port.to_s + "/")
      end

      describe "ssl" do
        context "when SSL is true" do
          let(:ssl) { true }
          let(:base_options) { super().merge(:hosts => [http_hostname_port]) }

          it "should refuse to handle an http url" do
            expect {
              subject.host_to_url(http_hostname_port)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end

        context "when SSL is false" do
          let(:ssl) { false }
          let(:base_options) { super().merge(:hosts => [https_hostname_port]) }
          
          it "should refuse to handle an https url" do
            expect {
              subject.host_to_url(https_hostname_port)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end

        describe "ssl is nil" do
          let(:base_options) { super().merge(:hosts => [https_hostname_port]) }
          it "should handle an ssl url correctly when SSL is nil" do
            subject
            expect(subject.host_to_url(https_hostname_port).to_s).to eq(https_hostname_port.to_s + "/")
          end
        end       
      end

      describe "path" do
        let(:url) { http_hostname_port_path }
        let(:base_options) { super().merge(:hosts => [url]) }
        
        it "should allow paths in a url" do
          expect(subject.host_to_url(url)).to eq(url)
        end

        context "with the path option set" do
          let(:base_options) { super().merge(:client_settings => {:path => "/otherpath"}) }

          it "should not allow paths in two places" do
            expect {
              subject.host_to_url(url)
            }.to raise_error(LogStash::ConfigurationError)
          end
        end
        
        context "with a path missing a leading /" do
          let(:url) { http_hostname_port }
          let(:base_options) { super().merge(:client_settings => {:path => "otherpath"}) }
          
          
          it "should automatically insert a / in front of path overlays" do
            expected = url.clone
            expected.path = url.path + "/otherpath"
            expect(subject.host_to_url(url)).to eq(expected)
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
      expect(subject.pool).to receive(:get).with(path, nil).and_return(get_response)
      expect(subject.get(path)["body"]).to eq(body)
    end
  end

  describe "index template" do
    subject { described_class.new(base_options) }
    let(:template_name) { "logstash" }
    let(:template) { {} }
    let(:get_response) {
      double("response", :body => {})
    }

    it "should call composable index template in version 8+" do
      expect(subject).to receive(:maximum_seen_major_version).and_return(8)
      expect(subject.pool).to receive(:put).with("_index_template/#{template_name}", nil, anything).and_return(get_response)
      subject.template_put(template_name, template)
    end

    it "should call index template in version < 8" do
      expect(subject).to receive(:maximum_seen_major_version).and_return(7)
      expect(subject.pool).to receive(:put).with("_template/#{template_name}", nil, anything).and_return(get_response)
      subject.template_put(template_name, template)
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

  describe "#bulk" do
    subject(:http_client) { described_class.new(base_options) }

    require "json"
    let(:message) { "hey" }
    let(:actions) { [
      ["index", {:_id=>nil, :_index=>"logstash"}, {"message"=> message}],
    ]}

    [true,false].each do |http_compression_enabled|
      context "with `http_compression => #{http_compression_enabled}`" do

        let(:base_options) { super().merge(:client_settings => {:http_compression => http_compression_enabled}) }

        before(:each) do
          if http_compression_enabled
            expect(http_client).to receive(:gzip_writer).at_least(:once).and_call_original
          else
            expect(http_client).to_not receive(:gzip_writer)
          end
        end

        context "if a message is over TARGET_BULK_BYTES" do
          let(:target_bulk_bytes) { LogStash::Outputs::ElasticSearch::TARGET_BULK_BYTES }
          let(:message) { "a" * (target_bulk_bytes + 1) }

          it "should be handled properly" do
            allow(subject).to receive(:join_bulk_responses)
            expect(subject).to receive(:bulk_send).once do |data|
              if !http_compression_enabled
                expect(data.size).to be > target_bulk_bytes
              else
                expect(Zlib::gunzip(data.string).size).to be > target_bulk_bytes
              end
            end
            s = subject.send(:bulk, actions)
          end
        end

        context "with two messages" do
          let(:message1) { "hey" }
          let(:message2) { "you" }
          let(:actions) { [
            ["index", {:_id=>nil, :_index=>"logstash"}, {"message"=> message1}],
            ["index", {:_id=>nil, :_index=>"logstash"}, {"message"=> message2}],
          ]}
          it "executes one bulk_send operation" do
            allow(subject).to receive(:join_bulk_responses)
            expect(subject).to receive(:bulk_send).once
            s = subject.send(:bulk, actions)
          end

          context "if one exceeds TARGET_BULK_BYTES" do
            let(:target_bulk_bytes) { LogStash::Outputs::ElasticSearch::TARGET_BULK_BYTES }
            let(:message1) { "a" * (target_bulk_bytes + 1) }
            it "executes two bulk_send operations" do
              allow(subject).to receive(:join_bulk_responses)
              expect(subject).to receive(:bulk_send).twice
              s = subject.send(:bulk, actions)
            end
          end
        end

        context "with partial unsupported action" do
          let(:actions) { [
            ["index", {:_id=>nil, :_index=>"logstash"}, {"message"=> "hello"}],
            ["unsupported_action", {:_id=>nil, :_index=>"logstash"}, {"message"=> "world!"}],
          ]}
          it "executes one bulk_send operation" do
            allow(subject).to receive(:join_bulk_responses)
            expect(subject).to receive(:bulk_send).once do |body_stream, batch_actions|
              action, source = batch_actions.first
              action_type, input_args, source = actions[0]
              expect(action["index"]).to match(input_args)
            end
            subject.send(:bulk, actions)
          end
        end
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

  class StoppableServer

    attr_reader :port

    def initialize()
      queue = Queue.new
      @first_req_waiter = java.util.concurrent.CountDownLatch.new(1)
      @first_request = nil

      @t = java.lang.Thread.new(
        proc do
          begin
            @server = WEBrick::HTTPServer.new :Port => 0, :DocumentRoot => ".",
                     :Logger => Cabin::Channel.get, # silence WEBrick logging
                     :StartCallback => Proc.new {
                           queue.push("started")
                         }
            @port = @server.config[:Port]
            @server.mount_proc '/headers_check' do |req, res|
              res.body = 'Hello, world from WEBrick mocking server!'
              @first_request = req
              @first_req_waiter.countDown()
            end

            @server.start
          rescue => e
            puts "Error in webserver thread #{e}"
            # ignore
          end
        end
      )
      @t.daemon = true
      @t.start
      queue.pop # blocks until the server is up
    end

    def stop
      @server.shutdown
    end

    def wait_receive_request
      @first_req_waiter.await(2, java.util.concurrent.TimeUnit::SECONDS)
      @first_request
    end
  end

  describe "#build_adapter" do
    let(:client) { LogStash::Outputs::ElasticSearch::HttpClient.new(base_options) }
    let!(:webserver) { StoppableServer.new } # webserver must be started before the call, so no lazy "let"

    after :each do
      webserver.stop
    end

    context "the 'user-agent' header" do
      it "contains the Logstash environment details" do
        adapter = client.build_adapter(client.options)
        adapter.perform_request(::LogStash::Util::SafeURI.new("http://localhost:#{webserver.port}"), :get, "/headers_check")

        request = webserver.wait_receive_request

        transmitted_user_agent = request.header['user-agent'][0]
        expect(transmitted_user_agent).to match(/Logstash\/\d*\.\d*\.\d* \(OS=.*; JVM=.*\) logstash-output-elasticsearch\/\d*\.\d*\.\d*/)
      end
    end
  end
end
