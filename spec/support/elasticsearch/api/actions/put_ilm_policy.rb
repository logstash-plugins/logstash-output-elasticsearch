# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.

module Elasticsearch
  module API
    module Actions

      COMMON_QUERY_PARAMS = [
        :ignore,                        # Client specific parameters
        :format,                        # Search, Cat, ...
        :pretty,                        # Pretty-print the response
        :human,                         # Return numeric values in human readable format
        :filter_path                    # Filter the JSON response
      ]

      # @option arguments [String] :name The name of the policy (*Required*)
      # @option arguments [Hash] :body The policy definition (*Required*)

      def put_ilm_policy(arguments={})
        raise ArgumentError, "Required argument 'name' missing" unless arguments[:name]
        raise ArgumentError, "Required argument 'body' missing" unless arguments[:body]
        method = HTTP_PUT
        path   = Utils.__pathify '_ilm/policy/', Utils.__escape(arguments[:name])
        params = __extract_params(arguments)
        body   = arguments[:body]
        perform_request(method, path, params, body.to_json).body
      end

      # This method was removed from elasticsearch-ruby client v8
      # Copied from elasticsearch-ruby v7 client to make it available
      #
      def __extract_params(arguments, params=[], options={})
        result = arguments.select { |k,v| COMMON_QUERY_PARAMS.include?(k) || params.include?(k) }
        result = Hash[result] unless result.is_a?(Hash) # Normalize Ruby 1.8 and Ruby 1.9 Hash#select behaviour
        result = Hash[result.map { |k,v| v.is_a?(Array) ? [k, Utils.__listify(v, options)] : [k,v]  }] # Listify Arrays
        result
      end
    end
  end
end
