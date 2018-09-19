module LogStash; module Outputs; class ElasticSearch
  class ILMManager
    # config :ilm_enabled, :validate => :boolean, :default => false
    #
    # # Write alias used for indexing data. If write alias doesn't exist, Logstash will create it and map it to the relevant index
    # config :ilm_write_alias, :validate => :string
    #
    # # appends “000001” by default for new index creation, subsequent rollover indices will increment based on this pattern i.e. “000002”
    # config :ilm_pattern, :validate => :string, :default => '000001'
    #
    # # ILM policy to use, if undefined the default policy will be used.
    # config :ilm_policy, :validate => :string, :default => 'logstash-policy'

    DEFAULT_POLICY="logstash-policy"

    def self.ilm_enabled?(plugin)
      plugin.ilm_enabled
    end

    def self.decorate_template(plugin, template)
      # Include ilm settings in template:
      template['settings'].update({ 'index.lifecycle.name' => plugin.ilm_policy, 'index.lifecycle.rollover_alias' => plugin.ilm_write_alias})
    end

    def self.maybe_create_write_alias(plugin, ilm_write_alias)
      plugin.client.write_alias_put(write_alias_target(plugin), write_alias_payload(plugin)) unless plugin.client.write_alias_exists?(ilm_write_alias)
    end

    def self.maybe_create_ilm_policy(plugin, ilm_policy)
      plugin.client.ilm_policy_put(ilm_policy, default_policy_payload) if ilm_policy == DEFAULT_POLICY && !plugin.client.ilm_policy_exists?(ilm_policy)
    end

    def self.write_alias_payload(plugin)
      {
        "aliases" => {
            plugin.ilm_write_alias =>{
                "is_write_index" =>  true
            }
        }
      }
    end

    def self.write_alias_target(plugin)
      "#{plugin.ilm_write_alias}-#{plugin.ilm_pattern}"
    end

    def self.default_policy_payload
      {
          "policy" => {
              "phases" => {
                  "hot" => {
                      "actions" => {
                          "rollover" => {
                              "max_size" => "25gb",
                              "max_age" =>   "30d"
                          }
                      }
                  }
              }
          }
      }
    end
  end
end end end