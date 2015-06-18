require "logstash/devutils/rspec/spec_helper"
require "ftw"
require "logstash/plugin"
require "logstash/json"
require "stud/try"
require "longshoreman"

CONTAINER_NAME = "logstash-output-elasticsearch-#{rand(999).to_s}"
CONTAINER_IMAGE = "elasticsearch"
CONTAINER_TAG = "1.6"

module ESHelper

  def get_host
    Longshoreman.new.get_host_ip
  end

  def get_port(protocol)
    container = Longshoreman::Container.new
    container.get(CONTAINER_NAME)
    case protocol
    when "http"
      container.rport(9200)
    when "transport", "node"
      container.rport(9300)
    end
  end

  def get_client
    Elasticsearch::Client.new(:host => "#{get_host}:#{get_port('http')}")
  end
end

RSpec.configure do |config|
  config.include ESHelper

  config.before(:suite, :integration => true) do
    @docker = Longshoreman.new("#{CONTAINER_IMAGE}:#{CONTAINER_TAG}", CONTAINER_NAME)
    # TODO(talevy): detect when ES is up and ready instead of sleeping
    # an arbitrary amount
    sleep 10
  end

  config.after(:suite, :integration => true) do
    @docker.cleanup
  end
end
