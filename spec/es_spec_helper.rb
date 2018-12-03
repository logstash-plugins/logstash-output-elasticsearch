require "logstash/devutils/rspec/spec_helper"
require 'manticore'
require 'elasticsearch'
require_relative "support/elasticsearch/api/actions/delete_ilm_policy"
require_relative "support/elasticsearch/api/actions/get_alias"
require_relative "support/elasticsearch/api/actions/put_alias"
require_relative "support/elasticsearch/api/actions/get_ilm_policy"
require_relative "support/elasticsearch/api/actions/put_ilm_policy"

require 'json'

module ESHelper
  def get_host_port
    "127.0.0.1:9200"
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port])
  end

  def doc_type
    if ESHelper.es_version_satisfies?(">=7")
      "_doc"
    else
      "doc"
    end
  end

  def todays_date
    Time.now.strftime("%Y.%m.%d")
  end

  def mapping_name
    if ESHelper.es_version_satisfies?(">=7")
      "_doc"
    else
      "_default_"
    end

  end

  def routing_field_name
    if ESHelper.es_version_satisfies?(">=6")
      :routing
    else
      :_routing
    end
  end

  def self.es_version
    RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
  end

  RSpec::Matchers.define :have_hits do |expected|
    es_version = RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
    match do |actual|
      if ESHelper.es_version_satisfies?(">=7")
        expected == actual['hits']['total']['value']
      else
        expected == actual['hits']['total']
      end
    end
  end


  def self.es_version_satisfies?(*requirement)
    es_version = RSpec.configuration.filter[:es_version] || ENV['ES_VERSION']
    if es_version.nil?
      puts "Info: ES_VERSION environment or 'es_version' tag wasn't set. Returning false to all `es_version_satisfies?` call."
      return false
    end
    es_release_version = Gem::Version.new(es_version).release
    Gem::Requirement.new(requirement).satisfied_by?(es_release_version)
  end

  def clean(client)
    client.indices.delete_template(:name => "*")
    # This can fail if there are no indexes, ignore failure.
    client.indices.delete(:index => "*") rescue nil
    clean_ilm(client) if supports_ilm?(client)
  end

  def set_cluster_settings(client, cluster_settings)
    client.cluster.put_settings(body: cluster_settings)
    get_cluster_settings(client)
  end

  def get_cluster_settings(client)
    client.cluster.get_settings
  end

  def get_policy(client, policy_name)
    client.get_ilm_policy(name: policy_name)
  end

  def put_policy(client, policy_name, policy)
    client.put_ilm_policy({:name => policy_name, :body=> policy})
  end

  def put_alias(client, the_alias, index)
    body = {
        "aliases" => {
            index => {
                "is_write_index"=>  true
            }
        }
    }
    client.put_alias({name: the_alias, body: body})
  end

  def clean_ilm(client)
    client.get_ilm_policy.each_key {|key| client.delete_ilm_policy(name: key)}
  end

  def supports_ilm?(client)
    begin
      client.get_ilm_policy
      true
    rescue
      false
    end
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
