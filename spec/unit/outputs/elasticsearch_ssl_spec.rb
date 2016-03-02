require_relative "../../../spec/es_spec_helper"
require 'stud/temporary'

describe "SSL option" do
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
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    it "should pass the flag to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to eq(:enabled => true, :verify => false)
      end
      subject.register
    end

    it "should print a warning" do
      disabled_matcher = /You have enabled encryption but DISABLED certificate verification/
      expect(subject.logger).to receive(:warn).with(disabled_matcher).at_least(:once)
      allow(subject.logger).to receive(:warn).with(any_args)
      subject.register
    end
  end

  context "when using ssl with client certificates" do
    let(:keystore_path) { Stud::Temporary.file.path }

    after :each do
      File.delete(keystore_path)
    end

    subject do
      require "logstash/outputs/elasticsearch"
      settings = {
        "hosts" => "node01",
        "ssl" => true,
        "keystore" => keystore_path,
        "keystore_password" => "test"
      }
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    it "should pass the keystore parameters to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to include(:keystore => keystore_path, :keystore_password => "test")
      end
      subject.register
    end

  end
end
