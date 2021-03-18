require_relative "../../../spec/spec_helper"
require 'stud/temporary'

describe "SSL option" do
  let(:manticore_double) { double("manticoreSSL #{self.inspect}") }
  before do
    allow(manticore_double).to receive(:close)
    
    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    
    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)

    allow(subject).to receive(:after_successful_connection) { |&block| block.call }
    allow(subject).to receive(:finish_register)
  end
  
  context "when using ssl without cert verification" do
    subject do
      require "logstash/outputs/elasticsearch"
      settings = {
        "hosts" => "localhost",
        "ssl" => true,
        "ssl_certificate_verification" => false,
        "pool_max" => 1,
        "pool_max_per_route" => 1
      }
      LogStash::Outputs::ElasticSearch.new(settings)
    end
    
    after do
      subject.close
    end
    
    it "should pass the flag to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to eq(:enabled => true, :verify => false)
      end.and_return(manticore_double)
      
      subject.register
    end

    it "should print a warning" do
      disabled_matcher = /You have enabled encryption but DISABLED certificate verification/
      expect(subject.logger).to receive(:warn).with(disabled_matcher).at_least(:once)
      allow(subject.logger).to receive(:warn).with(any_args)
      
      subject.register
      allow(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:start)
    end
  end

  context "when using ssl with client certificates" do
    let(:keystore_path) { Stud::Temporary.file.path }
    before do
      `openssl req -x509  -batch -nodes -newkey rsa:2048 -keyout lumberjack.key -out #{keystore_path}.pem`
    end

    after :each do
      File.delete(keystore_path)
      subject.close
    end

    subject do
      require "logstash/outputs/elasticsearch"
      settings = {
        "hosts" => "node01",
        "ssl" => true,
        "cacert" => keystore_path,
      }
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    it "should pass the keystore parameters to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to include(:keystore => keystore_path, :keystore_password => "test")
      end.and_call_original
      subject.register
    end

  end
end
