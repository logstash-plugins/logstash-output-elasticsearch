require "logstash/devutils/rspec/spec_helper"

require "logstash/outputs/elasticsearch"

module LogStash::Outputs::ElasticSearch::SpecHelper
end

RSpec.configure do |config|
  config.include LogStash::Outputs::ElasticSearch::SpecHelper
end
