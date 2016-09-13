require "logstash/devutils/rspec/spec_helper"
require 'elasticsearch'

module ESHelper
  def get_client(extra_host_opts = {})
    default_opts = { host: "localhost", port: "9200" }
    default_opts.merge!(extra_host_opts)
    print default_opts
    Elasticsearch::Client.new(:hosts => [ default_opts ])
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
