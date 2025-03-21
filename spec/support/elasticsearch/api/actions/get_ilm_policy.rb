# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.

module Elasticsearch
  module API
    module Actions

      # Retrieve the list of index lifecycle management policies
      def get_ilm_policy(arguments={})
        method = HTTP_GET
        path   = Utils.__pathify '_ilm/policy', Utils.__escape(arguments[:name])
        params = {}
        perform_request(method, path, params, nil).body
      end
    end
  end
end