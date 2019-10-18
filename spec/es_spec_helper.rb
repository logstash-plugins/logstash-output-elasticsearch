require "logstash/devutils/rspec/spec_helper"
require 'manticore'
require 'elasticsearch'
require_relative "support/elasticsearch/api/actions/delete_ilm_policy"
require_relative "support/elasticsearch/api/actions/get_alias"
require_relative "support/elasticsearch/api/actions/put_alias"
require_relative "support/elasticsearch/api/actions/get_ilm_policy"
require_relative "support/elasticsearch/api/actions/put_ilm_policy"

require 'json'

unless defined?(LogStash::OSS)
  LogStash::OSS = ENV['DISTRIBUTION'] != "default"
end

module ESHelper
  def get_host_port
    if ENV["INTEGRATION"] == "true"
      "elasticsearch:9200"
    else
      "localhost:9200"
    end
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port])
  end

  def doc_type
    if ESHelper.es_version_satisfies?(">=8")
      nil
    elsif ESHelper.es_version_satisfies?(">=7")
      "_doc"
    else
      "doc"
    end
  end

  def action_for_version(action)
    action_params = action[1]
    if ESHelper.es_version_satisfies?(">=8")
      action_params.delete(:_type)
    end
    action[1] = action_params
    action
  end

  def todays_date
    Time.now.strftime("%Y.%m.%d")
  end


  def default_mapping_from_mappings(mappings)
    if ESHelper.es_version_satisfies?(">=7")
      mappings
    else
      mappings["_default_"]
    end
  end

  def field_properties_from_template(template_name, field)
    mappings = @es.indices.get_template(name: template_name)[template_name]["mappings"]
    mapping = default_mapping_from_mappings(mappings)
    mapping["properties"][field]["properties"]
  end

  def routing_field_name
    if ESHelper.es_version_satisfies?(">=6")
      :routing
    else
      :_routing
    end
  end

  def self.es_version
    RSpec.configuration.filter[:es_version] || ENV['ES_VERSION'] || ENV['ELASTIC_STACK_VERSION']
  end

  RSpec::Matchers.define :have_hits do |expected|
    match do |actual|
      if ESHelper.es_version_satisfies?(">=7")
        expected == actual['hits']['total']['value']
      else
        expected == actual['hits']['total']
      end
    end
  end

  RSpec::Matchers.define :have_index_pattern do |expected|
    match do |actual|
      test_against = Array(actual['index_patterns'].nil? ? actual['template'] : actual['index_patterns'])
      test_against.include?(expected)
    end
  end


  def self.es_version_satisfies?(*requirement)
    es_version = RSpec.configuration.filter[:es_version] || ENV['ES_VERSION'] || ENV['ELASTIC_STACK_VERSION']
    if es_version.nil?
      puts "Info: ES_VERSION, ELASTIC_STACK_VERSION or 'es_version' tag wasn't set. Returning false to all `es_version_satisfies?` call."
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

  def max_docs_policy(max_docs)
  {
    "policy" => {
      "phases"=> {
        "hot" => {
          "actions" => {
            "rollover" => {
              "max_docs" => max_docs
            }
          }
        }
      }
    }
  }
  end

  def max_age_policy(max_age)
  {
    "policy" => {
      "phases"=> {
        "hot" => {
          "actions" => {
            "rollover" => {
              "max_age" => max_age
            }
          }
        }
      }
    }
  }
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
