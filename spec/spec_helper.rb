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


COMMON_QUERY_PARAMS = [
  :ignore,                        # Client specific parameters
  :format,                        # Search, Cat, ...
  :pretty,                        # Pretty-print the response
  :human,                         # Return numeric values in human readable format
  :filter_path                    # Filter the JSON response
]

# This method was removed from elasticsearch-ruby client v8
# Copied from elasticsearch-ruby v7 client to make it available
#
def __extract_params(arguments, params=[], options={})
  result = arguments.select { |k,v| COMMON_QUERY_PARAMS.include?(k) || params.include?(k) }
  result = Hash[result] unless result.is_a?(Hash) # Normalize Ruby 1.8 and Ruby 1.9 Hash#select behaviour
  result = Hash[result.map { |k,v| v.is_a?(Array) ? [k, Utils.__listify(v, options)] : [k,v]  }] # Listify Arrays
  result
end