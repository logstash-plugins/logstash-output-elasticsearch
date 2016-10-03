require "logstash/devutils/rspec/spec_helper"
require "ftw"
require 'elasticsearch'

module ESHelper
  def get_host_port
    "127.0.0.1:9200"
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port])
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
