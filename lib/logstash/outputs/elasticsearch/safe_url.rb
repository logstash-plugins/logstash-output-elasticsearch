module LogStash; module Outputs; class ElasticSearch;
  module SafeURL
    PLACEHOLDER = "~hidden~".freeze

    module_function

    # Takes a URI object and returns a copy of it with any user or password
    # information replaced with a placeholder `~hidden~`.
    def without_credentials(url)
      url.dup.tap do |u|
        u.user = PLACEHOLDER if u.user
        u.password = PLACEHOLDER if u.password
      end
    end
  end
end end end
