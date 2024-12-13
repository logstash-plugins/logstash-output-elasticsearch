require_relative "../../../spec/spec_helper"
require 'stud/temporary'

describe "SSL options" do
  let(:manticore_double) { double("manticoreSSL #{self.inspect}") }

  let(:settings) { { "ssl_enabled" => true, "hosts" => "localhost", "pool_max" => 1, "pool_max_per_route" => 1 } }

  subject do
    require "logstash/outputs/elasticsearch"
    LogStash::Outputs::ElasticSearch.new(settings)
  end

  before do
    allow(manticore_double).to receive(:close)

    response_double = double("manticore response").as_null_object
    # Allow healtchecks
    allow(manticore_double).to receive(:head).with(any_args).and_return(response_double)
    allow(manticore_double).to receive(:get).with(any_args).and_return(response_double)
    allow(::Manticore::Client).to receive(:new).and_return(manticore_double)
  end

  after do
    subject.close
  end

  context "when ssl_verification_mode" do
    context "is set to none" do
      let(:settings) { super().merge(
        "ssl_verification_mode" => 'none',
      ) }

      it "should print a warning" do
        expect(subject.logger).to receive(:warn).with(/You have enabled encryption but DISABLED certificate verification/).at_least(:once)
        allow(subject.logger).to receive(:warn).with(any_args)

        subject.register
        allow(LogStash::Outputs::ElasticSearch::HttpClient::Pool).to receive(:start)
      end

      it "should pass the flag to the ES client" do
        expect(::Manticore::Client).to receive(:new) do |args|
          expect(args[:ssl]).to match hash_including(:enabled => true, :verify => :disable)
        end.and_return(manticore_double)

        subject.register
      end
    end

    context "is set to full" do
      let(:settings) { super().merge(
        "ssl_verification_mode" => 'full',
      ) }

      it "should pass the flag to the ES client" do
        expect(::Manticore::Client).to receive(:new) do |args|
          expect(args[:ssl]).to match hash_including(:enabled => true, :verify => :default)
        end.and_return(manticore_double)

        subject.register
      end
    end
  end

  context "with the conflicting configs" do
    context "ssl_certificate_authorities and ssl_truststore_path set" do
      let(:ssl_truststore_path) { Stud::Temporary.file.path }
      let(:ssl_certificate_authorities_path) { Stud::Temporary.file.path }
      let(:settings) { super().merge(
        "ssl_truststore_path" => ssl_truststore_path,
        "ssl_certificate_authorities" => ssl_certificate_authorities_path
      ) }

      after :each do
        File.delete(ssl_truststore_path)
        File.delete(ssl_certificate_authorities_path)
      end

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, /Use either "ssl_certificate_authorities\/cacert" or "ssl_truststore_path\/truststore"/)
      end
    end

    context "ssl_certificate and ssl_keystore_path set" do
      let(:ssl_keystore_path) { Stud::Temporary.file.path }
      let(:ssl_certificate_path) { Stud::Temporary.file.path }
      let(:settings) { super().merge(
        "ssl_certificate" => ssl_certificate_path,
        "ssl_keystore_path" => ssl_keystore_path
      ) }

      after :each do
        File.delete(ssl_keystore_path)
        File.delete(ssl_certificate_path)
      end

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, /Use either "ssl_certificate" or "ssl_keystore_path\/keystore"/)
      end
    end
  end

  context "when configured with Java store files" do
    let(:ssl_truststore_path) { Stud::Temporary.file.path }
    let(:ssl_keystore_path) { Stud::Temporary.file.path }

    after :each do
      File.delete(ssl_truststore_path)
      File.delete(ssl_keystore_path)
    end

    let(:settings) { super().merge(
      "ssl_truststore_path" => ssl_truststore_path,
      "ssl_truststore_type" => "jks",
      "ssl_truststore_password" => "foo",
      "ssl_keystore_path" => ssl_keystore_path,
      "ssl_keystore_type" => "jks",
      "ssl_keystore_password" => "bar",
      "ssl_verification_mode" => "full",
      "ssl_cipher_suites" => ["TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"],
      "ssl_supported_protocols" => ["TLSv1.3"]
    ) }

    it "should pass the parameters to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to match hash_including(
                                      :enabled => true,
                                      :keystore => ssl_keystore_path,
                                      :keystore_type => "jks",
                                      :keystore_password => "bar",
                                      :truststore => ssl_truststore_path,
                                      :truststore_type => "jks",
                                      :truststore_password => "foo",
                                      :verify => :default,
                                      :cipher_suites => ["TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"],
                                      :protocols => ["TLSv1.3"],
                                    )
      end.and_return(manticore_double)

      subject.register
    end
  end

  context "when configured with certificate files" do
    let(:ssl_certificate_authorities_path) { Stud::Temporary.file.path }
    let(:ssl_certificate_path) { Stud::Temporary.file.path }
    let(:ssl_key_path) { Stud::Temporary.file.path }
    let(:settings) { super().merge(
      "ssl_certificate_authorities" => [ssl_certificate_authorities_path],
      "ssl_certificate" => ssl_certificate_path,
      "ssl_key" => ssl_key_path,
      "ssl_verification_mode" => "full",
      "ssl_cipher_suites" => ["TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"],
      "ssl_supported_protocols" => ["TLSv1.3"]
    ) }

    after :each do
      File.delete(ssl_certificate_authorities_path)
      File.delete(ssl_certificate_path)
      File.delete(ssl_key_path)
    end

    it "should pass the parameters to the ES client" do
      expect(::Manticore::Client).to receive(:new) do |args|
        expect(args[:ssl]).to match hash_including(
                                      :enabled => true,
                                      :ca_file => ssl_certificate_authorities_path,
                                      :client_cert => ssl_certificate_path,
                                      :client_key => ssl_key_path,
                                      :verify => :default,
                                      :cipher_suites => ["TLS_DHE_RSA_WITH_AES_256_CBC_SHA256"],
                                      :protocols => ["TLSv1.3"],
                                    )
      end.and_return(manticore_double)

      subject.register
    end

    context "and only the ssl_certificate is set" do
      let(:settings) { super().reject { |k| "ssl_key".eql?(k) } }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, /Using an "ssl_certificate" requires an "ssl_key"/)
      end
    end

    context "and only the ssl_key is set" do
      let(:settings) { super().reject { |k| "ssl_certificate".eql?(k) } }

      it "should raise a configuration error" do
        expect { subject.register }.to raise_error(LogStash::ConfigurationError, /An "ssl_certificate" is required when using an "ssl_key"/)
      end
    end
  end
end

# Move outside the SSL options describe block that has the after hook
describe "SSL obsolete settings" do
  let(:base_settings) { { "hosts" => "localhost", "pool_max" => 1, "pool_max_per_route" => 1 } }
  [
    {name: 'ssl', replacement: 'ssl_enabled'},
    {name: 'ssl_certificate_verification', replacement: 'ssl_verification_mode'},
    {name: 'cacert', replacement: 'ssl_certificate_authorities'},
    {name: 'truststore', replacement: 'ssl_truststore_path'},
    {name: 'keystore', replacement: 'ssl_keystore_path'},
    {name: 'truststore_password', replacement: 'ssl_truststore_password'},
    {name: 'keystore_password', replacement: 'ssl_keystore_password'}
  ].each do |obsolete_setting|
    context "with option #{obsolete_setting[:name]}" do
      let(:settings) { base_settings.merge(obsolete_setting[:name] => "value") }

      it "emits an error about the setting being obsolete" do
        error_text = /The setting `#{obsolete_setting[:name]}` in plugin `elasticsearch` is obsolete and is no longer available. (Use|Set) '#{obsolete_setting[:replacement]}' instead/i
        expect { LogStash::Outputs::ElasticSearch.new(settings) }.to raise_error LogStash::ConfigurationError, error_text
      end
    end
  end
end