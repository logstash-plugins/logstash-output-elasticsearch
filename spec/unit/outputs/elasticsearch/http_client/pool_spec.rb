require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require 'cabin'

describe LogStash::Outputs::ElasticSearch::HttpClient::Pool do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 2, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests
  let(:es_node_versions) { [ "0.0.0" ] }
  let(:oss) { true }
  let(:valid_license) { true }

  subject { described_class.new(logger, adapter, initial_urls, options) }

  let(:manticore_double) { double("manticore a") }
  before(:each) do
    stub_const('LogStash::OSS', oss)

    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:close)

    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)

    allow(subject).to receive(:get_es_version).with(any_args).and_return(*es_node_versions)
    allow(subject.license_checker).to receive(:oss?).and_return(oss)
    allow(subject.license_checker).to receive(:valid_es_license?).and_return(valid_license)
  end

  after do
    subject.close
  end

  describe "initialization" do
    it "should be successful" do
      expect { subject }.not_to raise_error
      subject.start
    end
  end

  describe "the resurrectionist" do
    before(:each) { subject.start }
    it "should start the resurrectionist when created" do
      expect(subject.resurrectionist_alive?).to eql(true)
    end

    it "should attempt to resurrect connections after the ressurrect delay" do
      expect(subject).to receive(:healthcheck!).once
      sleep(subject.resurrect_delay + 1)
    end

    describe "healthcheck url handling" do
      let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }

      context "and not setting healthcheck_path" do
        it "performs the healthcheck to the root" do
          expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
            expect(method).to eq(:head)
            expect(url.path).to be_empty
            expect(req_path).to eq("/")
          end
          subject.healthcheck!
        end
      end

      context "and setting healthcheck_path" do
        let(:healthcheck_path) { "/my/health" }
        let(:options) { super.merge(:healthcheck_path => healthcheck_path) }
        it "performs the healthcheck to the healthcheck_path" do
          expect(adapter).to receive(:perform_request) do |url, method, req_path, _, _|
            expect(method).to eq(:head)
            expect(url.path).to be_empty
            expect(req_path).to eq(healthcheck_path)
          end
          subject.healthcheck!
        end
      end
    end
  end

  describe 'resolving the address from Elasticsearch node info' do
    let(:host) { "node.elastic.co"}
    let(:ip_address) { "192.168.1.0"}
    let(:port) { 9200 }

    context 'in Elasticsearch 1.x format' do
      context 'with host and ip address' do
        let(:publish_address) { "inet[#{host}/#{ip_address}:#{port}]"}
        it 'should correctly extract the host' do
          expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{host}:#{port}"))
        end
      end
      context 'with ip address' do
        let(:publish_address) { "inet[/#{ip_address}:#{port}]"}
        it 'should correctly extract the ip address' do
          expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{ip_address}:#{port}"))
        end
      end
    end

    context 'in Elasticsearch 2.x-6.x format' do
      let(:publish_address) { "#{ip_address}:#{port}"}
      it 'should correctly extract the ip address' do
        expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("//#{ip_address}:#{port}"))
      end
    end

    context 'in Elasticsearch 7.x'
    context 'with host and ip address' do
      let(:publish_address) { "#{host}/#{ip_address}:#{port}"}
      it 'should correctly extract the host' do
        expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{host}:#{port}"))
      end
    end
    context 'with ip address' do
      let(:publish_address) { "#{ip_address}:#{port}"}
      it 'should correctly extract the ip address' do
        expect(subject.address_str_to_uri(publish_address)).to eq (LogStash::Util::SafeURI.new("#{ip_address}:#{port}"))
      end
    end
  end

  describe "the sniffer" do
    before(:each) { subject.start }
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
      subject.start
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
    before(:each) { subject.start }
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

  describe "version tracking" do
    let(:initial_urls) { [
      ::LogStash::Util::SafeURI.new("http://somehost:9200"),
      ::LogStash::Util::SafeURI.new("http://otherhost:9201")
    ] }

    before(:each) do
      allow(subject).to receive(:perform_request_to_url).and_return(nil)
      subject.start
    end

    it "picks the largest major version" do
      expect(subject.maximum_seen_major_version).to eq(0)
    end

    context "if there are nodes with multiple major versions" do
      let(:es_node_versions) { [ "0.0.0", "6.0.0" ] }
      it "picks the largest major version" do
        expect(subject.maximum_seen_major_version).to eq(6)
      end
    end
  end

  describe "license checking" do
    before(:each) do
      allow(subject).to receive(:health_check_request)
    end

    let(:options) do
      super.merge(:license_checker => license_checker)
    end

    context 'when LicenseChecker#acceptable_license? returns false' do
      let(:license_checker) { double('LicenseChecker', :appropriate_license? => false) }

      it 'does not mark the URL as active' do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(0)
      end
    end

    context 'when LicenseChecker#acceptable_license? returns true' do
      let(:license_checker) { double('LicenseChecker', :appropriate_license? => true) }

      it 'marks the URL as active' do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(1)
      end
    end
  end

  # TODO: extract to ElasticSearchOutputLicenseChecker unit spec
  describe "license checking with ElasticSearchOutputLicenseChecker" do
    let(:options) do
      super().merge(:license_checker => LogStash::Outputs::ElasticSearch::LicenseChecker.new(logger))
    end

    before(:each) do
      allow(subject).to receive(:health_check_request)
    end

    context "when using default logstash distribution" do
      let(:oss) { false }

      context "if ES doesn't return a valid license" do
        let(:valid_license) { false }

        it "marks the url as active" do
          subject.update_initial_urls
          expect(subject.alive_urls_count).to eq(1)
        end

        it "logs a warning" do
          expect(subject.license_checker).to receive(:log_license_deprecation_warn).once
          subject.update_initial_urls
        end
      end

      context "if ES returns a valid license" do
        let(:valid_license) { true }

        it "marks the url as active" do
          subject.update_initial_urls
          expect(subject.alive_urls_count).to eq(1)
        end

        it "does not log a warning" do
          expect(subject.license_checker).to_not receive(:log_license_deprecation_warn)
          subject.update_initial_urls
        end
      end
    end
  end
end
