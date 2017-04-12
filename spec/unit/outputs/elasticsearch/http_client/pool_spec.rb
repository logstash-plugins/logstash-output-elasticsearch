require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "json"

describe LogStash::Outputs::ElasticSearch::HttpClient::Pool do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 2, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests

  subject { described_class.new(logger, adapter, initial_urls, options) }

  let(:manticore_double) { double("manticore a") }
  before do

    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:close)

    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)

    subject.start
  end

  after do
    subject.close
  end

  describe "initialization" do
    it "should be successful" do
      expect { subject }.not_to raise_error
    end
  end

  describe "the resurrectionist" do
    it "should start the resurrectionist when created" do
      expect(subject.resurrectionist_alive?).to eql(true)
    end

    it "should attempt to resurrect connections after the ressurrect delay" do
      expect(subject).to receive(:healthcheck!).once
      sleep(subject.resurrect_delay + 1)
    end

    describe "healthcheck url handling" do
      let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200#{path}")] }
      let(:healthcheck_path) { "/some/other/path" }
      let(:absolute_healthcheck_path) { false }
      let(:path) { "/meh" }
      let(:options) { super.merge(:absolute_healthcheck_path => absolute_healthcheck_path, :path => path, :healthcheck_path => healthcheck_path) }

      context "when using query params in the initial url" do
        let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200?q=s")] }
        it "is removed from the healthcheck request" do
          expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
            expect(method).to eq(:head)
            expect(url.query).to be_nil
          end
          subject.healthcheck!
        end
      end

      describe "absolute_healthcheck_path" do
        context "when enabled" do
          let(:absolute_healthcheck_path) { true }
          it "should use the healthcheck_path as the absolute path" do
            expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
              expect(method).to eq(:head)
              expect(req_path).to eq(healthcheck_path)
              expect(url.path).to eq("/")
            end
            subject.healthcheck!
          end
        end

        context "when disabled" do
          let(:absolute_healthcheck_path) { false }
          it "should use the healthcheck_path as a relative path" do
            expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
              expect(method).to eq(:head)
              expect(req_path).to eq(healthcheck_path)
              expect(url.path).to eq(path)
            end
            subject.healthcheck!
          end
        end
      end
    end
  end

  describe "the sniffer" do
    it "should not start the sniffer by default" do
      expect(subject.sniffer_alive?).to eql(nil)
    end

    context "when enabled" do
      let(:options) { super.merge(:sniffing => true)}

      it "should start the sniffer" do
        expect(subject.sniffer_alive?).to eql(true)
      end
    end
    describe "absolute_sniffing_path" do
      let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200#{path}")] }
      let(:path) { "/meh" }
      let(:options) { super.merge(:absolute_sniffing_path => absolute_sniffing_path, :path => path, :sniffing_path => sniffing_path) }
      let(:sniffing_path) { "/some/other/path" }
      let(:absolute_sniffing_path) { false }
      let(:response) { double("manticore_response") }

      before(:each) { allow(response).to receive(:body).and_return("{}") }

      context "when enabled" do
        let(:absolute_sniffing_path) { true }
        it "should use the sniffing_path as the absolute path" do
          expect(subject).to receive(:perform_request_to_url) do |url, method, req_path, _, _|
            expect(method).to eq(:get)
            expect(req_path).to eq(sniffing_path)
            expect(url.path).to eq("/")
            response
          end
          subject.check_sniff
        end
      end

      context "when disabled" do
        let(:absolute_sniffing_path) { false }
        it "should use the sniffing_path as a relative path" do
          expect(subject).to receive(:perform_request_to_url) do |url, method, req_path, _, _|
            expect(method).to eq(:get)
            expect(req_path).to eq(sniffing_path)
            expect(url.path).to eq(path)
            response
          end
          subject.check_sniff
        end
      end
    end
  end

  describe "closing" do
    before do
      # Simulate a single in use connection on the first check of this
      allow(adapter).to receive(:close).and_call_original
      allow(subject).to receive(:wait_for_in_use_connections).and_call_original
      allow(subject).to receive(:in_use_connections).and_return([subject.empty_url_meta()],[])
      allow(subject).to receive(:start)
      subject.close
    end

    it "should close the adapter" do
      expect(adapter).to have_received(:close)
    end

    it "should stop the resurrectionist" do
      expect(subject.resurrectionist_alive?).to eql(false)
    end

    it "should stop the sniffer" do
      # If no sniffer (the default) returns nil
      expect(subject.sniffer_alive?).to be_falsey
    end

    it "should wait for in use connections to terminate" do
      expect(subject).to have_received(:wait_for_in_use_connections).once
      expect(subject).to have_received(:in_use_connections).twice
    end
  end

  describe "connection management" do
    context "with only one URL in the list" do
      it "should use the only URL in 'with_connection'" do
        subject.with_connection do |c|
          expect(c).to eq(initial_urls.first)
        end
      end
    end

    context "with multiple URLs in the list" do
      before :each do
        allow(adapter).to receive(:perform_request).with(anything, :head, subject.healthcheck_path, {}, nil)
      end
      let(:initial_urls) { [ ::LogStash::Util::SafeURI.new("http://localhost:9200"), ::LogStash::Util::SafeURI.new("http://localhost:9201"), ::LogStash::Util::SafeURI.new("http://localhost:9202") ] }

      it "should minimize the number of connections to a single URL" do
        connected_urls = []

        # If we make 2x the number requests as we have URLs we should
        # connect to each URL exactly 2 times
        (initial_urls.size*2).times do
          u, meta = subject.get_connection
          connected_urls << u
        end

        connected_urls.each {|u| subject.return_connection(u) }
        initial_urls.each do |url|
          conn_count = connected_urls.select {|u| u == url}.size
          expect(conn_count).to eql(2)
        end
      end

      it "should correctly resurrect the dead" do
        u,m = subject.get_connection

        # The resurrectionist will call this to check on the backend
        response = double("response")
        expect(adapter).to receive(:perform_request).with(u, :head, subject.healthcheck_path, {}, nil).and_return(response)

        subject.return_connection(u)
        subject.mark_dead(u, Exception.new)

        expect(subject.url_meta(u)[:state]).to eql(:dead)
        sleep subject.resurrect_delay + 1
        expect(subject.url_meta(u)[:state]).to eql(:alive)
      end
    end
  end
end
