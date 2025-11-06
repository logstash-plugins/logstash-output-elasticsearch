require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require 'cabin'

describe LogStash::Outputs::ElasticSearch::HttpClient::Pool do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(logger, {}) }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 3, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests
  let(:license_status) { 'active' }
  let(:root_response) { MockResponse.new(200,
                                          {"tagline" => "You Know, for Search",
                                           "version" => {
                                             "number" => '8.9.0',
                                             "build_flavor" => 'default'} },
                                          { "X-Elastic-Product" => "Elasticsearch" }
  ) }

  subject { described_class.new(logger, adapter, initial_urls, options) }

  let(:manticore_double) { double("manticore a") }
  before(:each) do
    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:close)

    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)

    allow(subject.license_checker).to receive(:license_status).and_return(license_status)
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

  describe "healthcheck" do

    describe "the resurrectionist" do
      before(:each) { subject.start }
      it "should start the resurrectionist when created" do
        expect(subject.resurrectionist_alive?).to eql(true)
      end

      it "should attempt to resurrect connections after the ressurrect delay" do
        expect(subject).to receive(:healthcheck!).once
        sleep(subject.resurrect_delay + 1)
      end
    end

    describe "healthcheck path handling" do
      let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
      let(:healthcheck_response) { double("Response", :code => 200) }

      before(:example) do
        subject.start

        expect(adapter).to receive(:perform_request).with(anything, :head, eq(healthcheck_path), anything, anything) do |url, _, _, _, _|
          expect(url.path).to be_empty
          healthcheck_response
        end

        expect(adapter).to receive(:perform_request).with(anything, :get, "/", anything, anything) do |url, _, _, _, _|
          expect(url.path).to be_empty
          root_response
        end
      end

      context "and not setting healthcheck_path" do
        let(:healthcheck_path) { "/" }
        it "performs the healthcheck to the root" do
          subject.healthcheck!
        end
      end

      context "and setting healthcheck_path" do
        let(:healthcheck_path) { "/my/health" }
        let(:options) { super().merge(:healthcheck_path => healthcheck_path) }
        it "performs the healthcheck to the healthcheck_path" do
          subject.healthcheck!
        end
      end
    end

    describe "register phase" do
      shared_examples_for "root path returns bad code error" do |err_msg|
        before :each do
          subject.update_initial_urls
          expect(subject).to receive(:elasticsearch?).never
        end

        it "raises ConfigurationError" do
          expect(subject).to receive(:health_check_request).with(anything).and_return(["", nil])
          expect(subject).to receive(:get_root_path).with(anything).and_return([nil,
                                                                                ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(mock_resp.code, nil, nil, mock_resp.body)])
          expect { subject.healthcheck! }.to raise_error(LogStash::ConfigurationError, err_msg)
        end
      end

      context "with 200 without version" do
        let(:mock_resp) { MockResponse.new(200, {"tagline" => "You Know, for Search"}) }

        it "raises ConfigurationError" do
          subject.update_initial_urls

          expect(subject).to receive(:health_check_request).with(anything).and_return(["", nil])
          expect(subject).to receive(:get_root_path).with(anything).and_return([mock_resp, nil])
          expect { subject.healthcheck! }.to raise_error(LogStash::ConfigurationError, "Could not connect to a compatible version of Elasticsearch")
        end
      end

      context "with 200 serverless" do
        let(:good_resp) { MockResponse.new(200,
                                           { "tagline" => "You Know, for Search",
                                             "version" => { "number" => '8.10.0', "build_flavor" => 'serverless'}
                                           },
                                           { "X-Elastic-Product" => "Elasticsearch" }
        ) }
        let(:bad_400_err) do
          ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(400,
           nil, nil,
           "The requested [Elastic-Api-Version] header value of [2024-10-31] is not valid. Only [2023-10-31] is supported")
        end

        it "raises ConfigurationError when the serverless connection test fails" do
          subject.update_initial_urls

          expect(subject).to receive(:health_check_request).with(anything).and_return(["", nil])
          expect(subject).to receive(:get_root_path).with(anything).and_return([good_resp, nil])
          expect(subject).to receive(:get_root_path).with(anything, hash_including(:headers => LogStash::Outputs::ElasticSearch::HttpClient::Pool::DEFAULT_EAV_HEADER)).and_return([nil, bad_400_err])
          expect { subject.healthcheck! }.to raise_error(LogStash::ConfigurationError, "The Elastic-Api-Version header is not valid")
        end

        it "passes when the serverless connection test succeeds" do
          subject.update_initial_urls

          expect(subject).to receive(:health_check_request).with(anything).and_return(["", nil])
          expect(subject).to receive(:get_root_path).with(anything).and_return([good_resp, nil])
          expect(subject).to receive(:get_root_path).with(anything, hash_including(:headers => LogStash::Outputs::ElasticSearch::HttpClient::Pool::DEFAULT_EAV_HEADER)).and_return([good_resp, nil])
          expect { subject.healthcheck! }.not_to raise_error
        end
      end

      context "with 200 default" do
        let(:good_resp) { MockResponse.new(200,
                                           { "tagline" => "You Know, for Search",
                                             "version" => { "number" => '8.10.0', "build_flavor" => 'default'}
                                           },
                                           { "X-Elastic-Product" => "Elasticsearch" }
        ) }

        it "passes without checking serverless connection" do
          subject.update_initial_urls

          expect(subject).to receive(:health_check_request).with(anything).and_return(["", nil])
          expect(subject).to receive(:get_root_path).with(anything).and_return([good_resp, nil])
          expect(subject).not_to receive(:get_root_path).with(anything, hash_including(:headers => LogStash::Outputs::ElasticSearch::HttpClient::Pool::DEFAULT_EAV_HEADER))
          expect { subject.healthcheck! }.not_to raise_error
        end
      end

      context "with 400" do
        let(:mock_resp) { MockResponse.new(400, "The requested [Elastic-Api-Version] header value of [2024-10-31] is not valid. Only [2023-10-31] is supported") }
        it_behaves_like "root path returns bad code error", "The Elastic-Api-Version header is not valid"
      end

      context "with 401" do
        let(:mock_resp) { MockResponse.new(401, "missing authentication") }
        it_behaves_like "root path returns bad code error", "Could not read Elasticsearch. Please check the credentials"
      end

      context "with 403" do
        let(:mock_resp) { MockResponse.new(403, "Forbidden") }
        it_behaves_like "root path returns bad code error", "Could not read Elasticsearch. Please check the privileges"
      end
    end

    describe "non register phase" do
      let(:health_bad_code_err) { ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(400, nil, nil, nil) }

      before :each do
        subject.update_initial_urls
      end

      it "does not call root path when health check request fails" do
        expect(subject).to receive(:health_check_request).with(anything).and_return(["", health_bad_code_err])
        expect(subject).to receive(:get_root_path).never
        subject.healthcheck!(false)
      end
    end
  end

  describe 'resolving the address from Elasticsearch node info' do
    let(:host) { "node.elastic.co"}
    let(:ip_address) { "192.168.1.0"}
    let(:port) { 9200 }

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
      let(:options) { super().merge(:sniffing => true)}

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

  class MockResponse
    attr_reader :code, :headers

    def initialize(code = 200, body = nil, headers = {})
        @code = code
        @body = body
        @headers = headers
    end

    def body
      @body.to_json
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
      let(:version_ok) do
        MockResponse.new(200, {"tagline" => "You Know, for Search",
                               "version" => {
                                 "number" => '7.13.0',
                                 "build_flavor" => 'default'}
                               })
      end
      let(:success_response) { double("head_req", :code => 200)}

      before :each do
        allow(adapter).to receive(:perform_request).with(anything, :head, subject.healthcheck_path, {}, nil).and_return(success_response)
        allow(adapter).to receive(:perform_request).with(anything, :get, subject.healthcheck_path, {}, nil).and_return(version_ok)
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
        response = double("response", :code => 200)
        expect(adapter).to receive(:perform_request).with(u, :head, subject.healthcheck_path, {}, nil).and_return(response)

        subject.return_connection(u)
        subject.mark_dead(u, Exception.new)

        expect(subject.url_meta(u)[:state]).to eql(:dead)
        sleep subject.resurrect_delay + 1
        # try a few times with exponential backoff as timing is not 100% guaranteed during CI execution.
        try(10) { expect(subject.url_meta(u)[:state]).to eql(:alive) }
      end
    end
  end

  describe "version tracking" do
    let(:initial_urls) { [
      ::LogStash::Util::SafeURI.new("http://somehost:9200"),
      ::LogStash::Util::SafeURI.new("http://otherhost:9201")
    ] }

    let(:root_response) { MockResponse.new(200, {"tagline" => "You Know, for Search",
                                                  "version" => {
                                                    "number" => '7.0.0',
                                                    "build_flavor" => 'default'}
    }) }
    let(:root_response2) { MockResponse.new(200,
                                            {
                                              "tagline" => "You Know, for Search",
                                              "version" => {
                                                "number" => '8.0.0',
                                                "build_flavor" => 'default'
                                              }
                                            },
                                            { "x-elastic-product" => "Elasticsearch" }
    ) }

    context "if there are nodes with multiple major versions" do
      before(:each) do
        allow(subject).to receive(:perform_request_to_url).and_return(root_response, root_response2)
        subject.start
      end

      it "picks the largest major version" do
        expect(subject.maximum_seen_major_version).to eq(8)
      end
    end
  end


  describe "build flavor tracking" do
    let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://somehost:9200")] }

    let(:root_response) { MockResponse.new(200,
                                            {"tagline" => "You Know, for Search",
                                                  "version" => {
                                                    "number" => '8.9.0',
                                                    "build_flavor" => LogStash::Outputs::ElasticSearch::HttpClient::Pool::BUILD_FLAVOR_SERVERLESS} },
                                            { "X-Elastic-Product" => "Elasticsearch" }
    ) }

    before(:each) do
      allow(subject).to receive(:perform_request_to_url).and_return(root_response)
      subject.start
    end

    it "picks the build flavor" do
      expect(subject.serverless?).to be_truthy
    end
  end

  describe "license checking" do
    before(:each) do
      allow(subject).to receive(:health_check_request).and_return(["", nil])
      allow(subject).to receive(:perform_request_to_url).and_return(root_response)
      allow(subject).to receive(:elasticsearch?).and_return(true)
    end

    let(:options) do
      super().merge(:license_checker => license_checker)
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

  describe "elastic api version header" do
    let(:eav) { "Elastic-Api-Version" }

    context "when it is serverless" do
      before(:each) do
        expect(subject).to receive(:serverless?).and_return(true)
      end

      it "add the default header" do
        expect(adapter).to receive(:perform_request).with(anything, :get, "/", anything, anything) do |_, _, _, params, _|
          expect(params[:headers]).to eq({ "User-Agent" => "chromium",  "Elastic-Api-Version" => "2023-10-31"})
        end
        subject.perform_request_to_url(initial_urls, :get, "/", { :headers => { "User-Agent" => "chromium" }} )
      end
    end

    context "when it is stateful" do
      before(:each) do
        expect(subject).to receive(:serverless?).and_return(false)
      end

      it "add the default header" do
        expect(adapter).to receive(:perform_request).with(anything, :get, "/", anything, anything) do |_, _, _, params, _|
          expect(params[:headers]).to be_nil
        end
        subject.perform_request_to_url(initial_urls, :get, "/" )
      end
    end
  end

  # TODO: extract to ElasticSearchOutputLicenseChecker unit spec
  describe "license checking with ElasticSearchOutputLicenseChecker" do
    let(:options) do
      super().merge(:license_checker => LogStash::Outputs::ElasticSearch::LicenseChecker.new(logger))
    end

    before(:each) do
      allow(subject).to receive(:health_check_request).and_return(["", nil])
      allow(subject).to receive(:perform_request_to_url).and_return(root_response)
      allow(subject).to receive(:elasticsearch?).and_return(true)
    end

    context "if ES doesn't return a valid license" do
      let(:license_status) { nil }

      it "marks the url as dead" do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(0)
      end

      it "logs a warning" do
        expect(subject.license_checker).to receive(:warn_no_license).once.and_call_original
        subject.update_initial_urls
      end
    end

    context "if ES returns a valid license" do
      let(:license_status) { 'active' }

      it "marks the url as active" do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(1)
      end

      it "does not log a warning" do
        expect(subject.license_checker).to_not receive(:warn_no_license)
        expect(subject.license_checker).to_not receive(:warn_invalid_license)
        subject.update_initial_urls
      end
    end

    context "if ES returns an invalid license" do
      let(:license_status) { 'invalid' }

      it "marks the url as active" do
        subject.update_initial_urls
        expect(subject.alive_urls_count).to eq(1)
      end

      it "logs a warning" do
        expect(subject.license_checker).to receive(:warn_invalid_license).and_call_original
        subject.update_initial_urls
      end
    end
  end
end

describe "#elasticsearch?" do
  let(:logger) { Cabin::Channel.get }
  let(:adapter) { double("Manticore Adapter") }
  let(:initial_urls) { [::LogStash::Util::SafeURI.new("http://localhost:9200")] }
  let(:options) { {:resurrect_delay => 2, :url_normalizer => proc {|u| u}} } # Shorten the delay a bit to speed up tests

  subject { LogStash::Outputs::ElasticSearch::HttpClient::Pool.new(logger, adapter, initial_urls, options) }

  context "when connecting to a cluster which reply without 'version' field" do
    it "should fail" do
      resp = MockResponse.new(200, {"field" => "funky.com"} )
      expect(subject.send(:elasticsearch?, resp)).to be false
    end
  end

  context "when connecting to a cluster with version in [7.0.0..7.14.0)" do
    it "must be successful is 'build_flavor' is 'default' and tagline is correct" do
      resp = MockResponse.new(200, {"version": {"number": "7.5.0", "build_flavor": "default"}, "tagline": "You Know, for Search"} )
      expect(subject.send(:elasticsearch?, resp)).to be true
    end

    it "should fail if 'build_flavor' is not 'default' and tagline is correct" do
      resp = MockResponse.new(200, {"version": {"number": "7.5.0", "build_flavor": "oss"}, "tagline": "You Know, for Search"} )
      expect(subject.send(:elasticsearch?, resp)).to be false
    end

    it "should fail if 'build_flavor' is not present and tagline is correct" do
      resp = MockResponse.new(200, {"version": {"number": "7.5.0"}, "tagline": "You Know, for Search"} )
      expect(subject.send(:elasticsearch?, resp)).to be false
    end
  end

  context "when connecting to a cluster with version >= 7.14.0" do
    it "should fail if 'X-elastic-product' header is not present" do
      resp = MockResponse.new(200, {"version": {"number": "7.14.0"}} )
      expect(subject.send(:elasticsearch?, resp)).to be false
    end

    it "should fail if 'X-elastic-product' header is present but with bad value" do
      resp = MockResponse.new(200, {"version": {"number": "7.14.0"}}, {'X-elastic-product' => 'not good'} )
      expect(subject.send(:elasticsearch?, resp)).to be false
    end

    it "must be successful when 'X-elastic-product' header is present with 'Elasticsearch' value" do
      resp = MockResponse.new(200, {"version": {"number": "7.14.0"}}, {'X-elastic-product' => 'Elasticsearch'} )
      expect(subject.send(:elasticsearch?, resp)).to be true
    end
  end
end
