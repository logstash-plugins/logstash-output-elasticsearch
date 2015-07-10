require_relative "../../../spec/es_spec_helper"
require 'stud/temporary'

describe "SSL option" do
  ["node", "transport"].each do |protocol|
    context "with protocol => #{protocol}" do
      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "protocol" => protocol,
          "node_name" => "logstash",
          "cluster" => "elasticsearch",
          "host" => "node01",
          "ssl" => true
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should fail in register" do
        expect {subject.register}.to raise_error
      end
    end
  end

  context "when using http protocol" do
    protocol = "http"
    context "when using ssl without cert verification" do
      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "protocol" => protocol,
          "host" => "node01",
          "ssl" => true,
          "ssl_certificate_verification" => false
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should pass the flag to the ES client" do
        expect(::Elasticsearch::Client).to receive(:new) do |args|
          expect(args[:ssl]).to eq(:verify => false)
        end
        subject.register
      end

      it "print a warning" do
        expect(subject.logger).to receive(:warn)
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
          "protocol" => protocol,
          "host" => "node01",
          "ssl" => true,
          "keystore" => keystore_path,
          "keystore_password" => "test"
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end


      it "should pass the keystore parameters to the ES client" do
        expect(::Elasticsearch::Client).to receive(:new) do |args|
          expect(args[:ssl]).to include(:keystore => keystore_path, :keystore_password => "test")
        end
        subject.register
      end

    end
  end
end
