require_relative "../../../spec/es_spec_helper"
require 'stud/temporary'
require "logstash/outputs/elasticsearch"
require 'manticore/client'

describe "Proxy option" do
  let(:settings) { { "hosts" => "node01" } }
  subject {
    LogStash::Outputs::ElasticSearch.new(settings)
  }

  before do
    allow(::Manticore::Client).to receive(:new).with(any_args).and_call_original
  end

  after do
    subject.close
  end

  describe "valid configs" do
    before do
      subject.register
    end

    context "when specified as a URI" do
      shared_examples("hash conversion") do |hash|
        let(:settings) { super.merge("proxy" => proxy)}
        
        it "should set the proxy to the correct hash value" do
          expect(::Manticore::Client).to have_received(:new) do |options|
            expect(options[:proxy]).to eq(hash)
          end
        end
      end
      
      describe "simple proxy" do
        let(:proxy) { LogStash::Util::SafeURI.new("http://127.0.0.1:1234") }

        include_examples("hash conversion",
          {
            :host => "127.0.0.1",
            :scheme => "http",
            :port => 1234  
          }
        )
      end
      
      
      describe "a secure authed proxy" do
        let(:proxy) { LogStash::Util::SafeURI.new("https://myuser:mypass@127.0.0.1:1234") }

        include_examples("hash conversion",
          {
            :host => "127.0.0.1",
            :scheme => "https",
            :user => "myuser",
            :password => "mypass",
            :port => 1234  
          }
        )
      end
    end

    context "when not specified" do
      it "should not send the proxy option to manticore" do
        expect(::Manticore::Client).to have_received(:new) do |options|
          expect(options).not_to include(:proxy)
        end
      end
    end
  end
end
