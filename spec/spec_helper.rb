require "logstash/devutils/rspec/spec_helper"

require "logstash/outputs/elasticsearch"

module LogStash::Outputs::ElasticSearch::SpecHelper
end

RSpec.configure do |config|
  config.include LogStash::Outputs::ElasticSearch::SpecHelper
end

# remove once plugin starts consuming elasticsearch-ruby v8 client
def elastic_ruby_v8_client_available?
  Elasticsearch::Transport
  false
rescue NameError # NameError: uninitialized constant Elasticsearch::Transport if Elastic Ruby client is not available
  true
end