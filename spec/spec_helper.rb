require "logstash/devutils/rspec/spec_helper"

require "logstash/outputs/elasticsearch"

module LogStash::Outputs::ElasticSearch::SpecHelper
end

RSpec.configure do |config|
  config.include LogStash::Outputs::ElasticSearch::SpecHelper
end


def elastic_ruby_v8_client_available?
  Elasticsearch::Transport
  false
rescue NameError # NameError: uninitialized constant Elasticsearch::Transport if Elastic Ruby client is not available
  true
end

def generate_common_index_params(index, doc_id)
  params = {:index => index, :id => doc_id, :refresh => true}
  params[:type] = doc_type unless elastic_ruby_v8_client_available?
  params
end