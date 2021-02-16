require "logstash/devutils/rspec/spec_helper"

unless defined?(LogStash::OSS)
  LogStash::OSS = ENV['DISTRIBUTION'] != "default"
end

require "logstash/outputs/elasticsearch"

module LogStash::Outputs::ElasticSearch::SpecHelper

  # Stub plugin's http client for unit testing.
  def stub_client(subject)
    # Build the client and set mocks before calling register to avoid races.
    subject.build_client

    # Rspec mocks can't handle background threads, so... we can't use any
    allow(subject.client.pool).to receive(:start_resurrectionist)
    allow(subject.client.pool).to receive(:start_sniffer)
    allow(subject.client.pool).to receive(:healthcheck!)
    allow(subject.client).to receive(:get_xpack_info)

    # emulate 'successful' ES connection on the same thread
    allow(subject).to receive(:after_successful_connection) { |&block| block.call }
    allow(subject).to receive(:stop_after_successful_connection_thread)

    subject.client
  end

end

RSpec.configure do |config|
  config.include LogStash::Outputs::ElasticSearch::SpecHelper
end