require_relative "../../../spec/es_spec_helper"

describe "send messages to ElasticSearch using HTTPS", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "node_name" => "logstash",
      "cluster" => "elasticsearch",
      "hosts" => "node01",
      "user" => "user",
      "password" => "changeme",
      "ssl" => true,
      "cacert" => "/tmp/ca/certs/cacert.pem",
      # or
      #"truststore" => "/tmp/ca/truststore.jks",
      #"truststore_password" => "testeteste"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    subject.register
  end

  it "sends events to ES" do
    expect {
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
    }.to_not raise_error
  end
end

describe "connect using HTTP Authentication", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "cluster" => "elasticsearch",
      "hosts" => "node01",
      "user" => "user",
      "password" => "changeme",
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    subject.register
  end

  it "sends events to ES" do
    expect {
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
    }.to_not raise_error
  end
end

describe "send messages to ElasticSearch using HTTPS", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "node_name" => "logstash",
      "cluster" => "elasticsearch",
      "hosts" => "node01",
      "user" => "user",
      "password" => "changeme",
      "ssl" => true,
      "cacert" => "/tmp/ca/certs/cacert.pem",
      # or
      #"truststore" => "/tmp/ca/truststore.jks",
      #"truststore_password" => "testeteste"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    subject.register
  end

  it "sends events to ES" do
    expect {
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
    }.to_not raise_error
  end
end

describe "connect using HTTP Authentication", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "hosts" => "node01",
      "user" => "user",
      "password" => "changeme",
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    subject.register
  end

  it "sends events to ES" do
    expect {
      subject.receive(LogStash::Event.new("message" => "sample message here"))
      subject.buffer_flush(:final => true)
    }.to_not raise_error
  end
end
