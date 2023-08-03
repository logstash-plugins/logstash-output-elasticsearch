require_relative './spec_helper'

require 'elasticsearch'
require_relative "support/elasticsearch/api/actions/delete_ilm_policy"
require_relative "support/elasticsearch/api/actions/get_alias"
require_relative "support/elasticsearch/api/actions/put_alias"
require_relative "support/elasticsearch/api/actions/get_ilm_policy"
require_relative "support/elasticsearch/api/actions/put_ilm_policy"

require 'json'
require 'cabin'

module ESHelper
  def get_host_port
    if ENV["INTEGRATION"] == "true"
      "elasticsearch:9200"
    else
      "localhost:9200"
    end
  end

  def get_client
    Elasticsearch::Client.new(:hosts => [get_host_port]).tap do |client|
      allow(client).to receive(:verify_elasticsearch).and_return(true) # bypass client side version checking
    end
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

  def self.action_for_version(action)
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

  def field_properties_from_template(template_name, field)
    template = get_template(@es, template_name)
    mappings = get_template_mappings(template)
    mappings["properties"][field]["properties"]
  end

  def routing_field_name
    :routing
  end

  def self.es_version
    {
      "version" => {
        "number" => [
          nilify(RSpec.configuration.filter[:es_version]),
          nilify(ENV['ES_VERSION']),
          nilify(ENV['ELASTIC_STACK_VERSION']),
        ].compact.first,
        "build_flavor" => 'default'
      }
    }
  end

  RSpec::Matchers.define :have_hits do |expected|
    hits_count_path = ESHelper.es_version_satisfies?(">=7") ? %w(hits total value) : %w(hits total)

    match do |actual|
      @actual_hits_count = actual&.dig(*hits_count_path)
      values_match? expected, @actual_hits_count
    end
    failure_message do |actual|
      "expected that #{actual} with #{@actual_hits_count || "UNKNOWN" } hits would have #{expected} hits"
    end
  end

  RSpec::Matchers.define :have_index_pattern do |expected|
    match do |actual|
      @actual_index_pattterns = Array(actual['index_patterns'].nil? ? actual['template'] : actual['index_patterns'])
      @actual_index_pattterns.any? { |v| values_match? expected, v }
    end
    failure_message do |actual|
      "expected that #{actual} with index patterns #{@actual_index_pattterns} would have included `#{expected}`"
    end
  end

  def self.es_version_satisfies?(*requirement)
    es_version = nilify(RSpec.configuration.filter[:es_version]) || nilify(ENV['ES_VERSION']) || nilify(ENV['ELASTIC_STACK_VERSION'])
    if es_version.nil?
      puts "Info: ES_VERSION, ELASTIC_STACK_VERSION or 'es_version' tag wasn't set. Returning false to all `es_version_satisfies?` call."
      return false
    end
    es_release_version = Gem::Version.new(es_version).release
    Gem::Requirement.new(requirement).satisfied_by?(es_release_version)
  end

  private
  def self.nilify(str)
    if str.nil?
      return str
    end
    str.empty? ? nil : str
  end

  public
  def clean(client)
    client.indices.delete_template(:name => "*")
    client.indices.delete_index_template(:name => "logstash*") rescue nil
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
    client.get_ilm_policy.each_key { |key| client.delete_ilm_policy(name: key)  if key =~ /logstash-policy/ }
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

  def get_template(client, name)
    if ESHelper.es_version_satisfies?(">=8")
      t = client.indices.get_index_template(name: name)
      t['index_templates'][0]['index_template']
    else
      t = client.indices.get_template(name: name)
      t[name]
    end
  end

  def get_template_settings(template)
    if ESHelper.es_version_satisfies?(">=8")
      template['template']['settings']
    else
      template['settings']
    end
  end

  def get_template_mappings(template)
    if ESHelper.es_version_satisfies?(">=8")
      template['template']['mappings']
    elsif ESHelper.es_version_satisfies?(">=7")
      template['mappings']
    else
      template['mappings']["_default_"]
    end
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
