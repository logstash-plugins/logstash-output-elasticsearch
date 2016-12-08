require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "json"

describe LogStash::Outputs::ElasticSearch::HttpClient::Pool do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger) }
  let(:initial_urls) { [URI.parse("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 2} } # Shorten the delay a bit to speed up tests

  subject { described_class.new(logger, adapter, initial_urls, options) }
  
  before do
    allow(adapter).to receive(:perform_request).with(anything, 'HEAD', subject.healthcheck_path, {}, nil)
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
  end

  describe "closing" do
    before do
      # Simulate a single in use connection on the first check of this
      allow(adapter).to receive(:close).and_call_original
      allow(subject).to receive(:wait_for_in_use_connections).and_call_original
      allow(subject).to receive(:in_use_connections).and_return([subject.empty_url_meta()],[])
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
  
  describe "safe_state_changes" do
    let(:state_changes) do 
      {
        :added => [URI.parse("http://sekretu:sekretp@foo1")],
        :removed => [URI.parse("http://sekretu:sekretp@foo2")]
      }
    end
    let(:processed) { subject.safe_state_changes(state_changes)}
    
    it "should hide passwords" do
      expect(processed[:added].any? {|p| p =~ /sekretp/ }).to be false
      expect(processed[:removed].any? {|p| p =~ /sekretp/ }).to be false
    end
  end

  describe "connection management" do
    context "with only one URL in the list" do
      it "should use the only URL in 'with_connection'" do
        subject.with_connection do |c|
          expect(c).to eql(initial_urls.first)
        end
      end
    end

    context "with multiple URLs in the list" do
      let(:initial_urls) { [ URI.parse("http://localhost:9200"), URI.parse("http://localhost:9201"), URI.parse("http://localhost:9202") ] }

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
        expect(adapter).to receive(:perform_request).with(u, 'HEAD', subject.healthcheck_path, {}, nil).and_return(response)

        subject.return_connection(u)
        subject.mark_dead(u, Exception.new)

        expect(subject.url_meta(u)[:state]).to eql(:dead)
        sleep subject.resurrect_delay + 1
        expect(subject.url_meta(u)[:state]).to eql(:alive)
      end
    end
  end
end
