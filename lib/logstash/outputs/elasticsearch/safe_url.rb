module LogStash; module Outputs; class ElasticSearch;
  module SafeURL
    module_function
    def without_credentials(url)
      url.dup.tap do |u|
        u.user = "~hidden~" if u.user
        u.password = "~hidden~" if u.password
      end
    end
  end
end end end
