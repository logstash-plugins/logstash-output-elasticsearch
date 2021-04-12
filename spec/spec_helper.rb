require "logstash/devutils/rspec/spec_helper"

unless defined?(LogStash::OSS)
  LogStash::OSS = ENV['DISTRIBUTION'] != "default"
end

require "logstash/outputs/elasticsearch"

module LogStash::Outputs::ElasticSearch::SpecHelper
end

RSpec.configure do |config|
  config.include LogStash::Outputs::ElasticSearch::SpecHelper
end