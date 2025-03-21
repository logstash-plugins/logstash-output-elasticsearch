# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.

module Elasticsearch
  module API
    module Actions

      # @option arguments [String] :name The name of the alias (*Required*)
      # @option arguments [Hash]   :The alias definition(*Required*)

      def put_alias(arguments={})
        raise ArgumentError, "Required argument 'name' missing" unless arguments[:name]
        raise ArgumentError, "Required argument 'body' missing" unless arguments[:body]
        method = HTTP_PUT
        path   = Utils.__pathify Utils.__escape(arguments[:name])

        params = Utils.__validate_and_extract_params arguments
        body   = arguments[:body]
        perform_request(method, path, params, body.to_json).body
      end
    end
  end
end
