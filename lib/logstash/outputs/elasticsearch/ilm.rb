module LogStash; module Outputs; class ElasticSearch
  module Ilm

    ILM_POLICY_PATH = "default-ilm-policy.json"

    def setup_ilm
      return if ilm_has_sprintf?

      logger.warn("Overwriting supplied index #{@index} with rollover alias #{@ilm_rollover_alias}") unless default_index?(@index)
      @index = @ilm_rollover_alias
      maybe_create_rollover_alias
      maybe_create_ilm_policy
    end

    def ilm_has_sprintf?
      (@ilm_rollover_alias && @ilm_rollover_alias.match(/%{.*?}/)) ||
        (@ilm_policy && @ilm_policy.match(/%{.*?}/))
    end

    def resolve_dynamic_ilm_rollover_alias!(event)
      resolve_dynamic_ilm_value!(event, @ilm_rollover_alias, "ilm_rollover_alias")
    end

    def resolve_dynamic_ilm_policy!(event)
      resolve_dynamic_ilm_value!(event, @ilm_policy, "ilm_policy")
    end

    def ensure_dynamic_ilm_resources!(event)
      return unless ilm_in_use? && ilm_has_sprintf?

      resolved_alias = resolve_dynamic_ilm_rollover_alias!(event)
      resolved_policy = resolve_dynamic_ilm_policy!(event)

      @dynamic_ilm_validation_lock ||= Mutex.new
      @dynamic_ilm_validated_keys ||= {}
      validation_key = "#{resolved_alias}|#{resolved_policy}"
      return if @dynamic_ilm_validated_keys[validation_key]

      @dynamic_ilm_validation_lock.synchronize do
        return if @dynamic_ilm_validated_keys[validation_key]

        unless client.ilm_policy_exists?(resolved_policy)
          raise EventMappingError, "Dynamic ILM policy '#{resolved_policy}' does not exist. " \
            "Pre-create policy, template, and rollover alias resources before using dynamic ILM."
        end

        unless client.rollover_alias_exists?(resolved_alias)
          raise EventMappingError, "Dynamic ILM rollover alias '#{resolved_alias}' does not exist. " \
            "Pre-create policy, template, and rollover alias resources before using dynamic ILM."
        end

        @dynamic_ilm_validated_keys[validation_key] = true
      end
    end

    def ilm_in_use?
      return @ilm_actually_enabled if defined?(@ilm_actually_enabled)
      @ilm_actually_enabled =
        begin
          if serverless?
            raise LogStash::ConfigurationError, "Invalid ILM configuration `ilm_enabled => true`. " +
              "Serverless Elasticsearch cluster does not support Index Lifecycle Management." if @ilm_enabled.to_s == 'true'
            @logger.info("ILM auto configuration (`ilm_enabled => auto` or unset) resolved to `false`. "\
              "Serverless Elasticsearch cluster does not support Index Lifecycle Management.") if @ilm_enabled == 'auto'
            false
          elsif @ilm_enabled == 'auto'
            ilm_alias_set?
          elsif @ilm_enabled.to_s == 'true'
            ilm_alias_set?
          else
            false
          end
        end
    end

    private

    def resolve_dynamic_ilm_value!(event, pattern, setting_name)
      resolved = event.sprintf(pattern)

      if resolved.nil? || resolved.empty?
        raise EventMappingError, "#{setting_name} resolved to empty value from pattern: #{pattern}"
      end

      if resolved.match(/%{.*?}/)
        raise EventMappingError, "#{setting_name} contains unresolved placeholders: #{resolved}"
      end

      resolved
    end

    def ilm_alias_set?
      default_index?(@index) || !default_rollover_alias?(@ilm_rollover_alias)
    end

    def default_index?(index)
      index == @default_index
    end

    def default_rollover_alias?(rollover_alias)
      rollover_alias == default_ilm_rollover_alias
    end

    def ilm_policy_default?
      ilm_policy == LogStash::Outputs::ElasticSearch::DEFAULT_POLICY
    end

    def maybe_create_ilm_policy
      if ilm_policy_default?
        client.ilm_policy_put(ilm_policy, policy_payload) unless client.ilm_policy_exists?(ilm_policy)
      else
        raise LogStash::ConfigurationError, "The specified ILM policy #{ilm_policy} does not exist on your Elasticsearch instance" unless client.ilm_policy_exists?(ilm_policy)
      end
    end

    def maybe_create_rollover_alias
      client.rollover_alias_put(rollover_alias_target, rollover_alias_payload) unless client.rollover_alias_exists?(ilm_rollover_alias)
    end

    def rollover_alias_target
      "<#{ilm_rollover_alias}-#{ilm_pattern}>"
    end

    def rollover_alias_payload
      {
          'aliases' => {
              ilm_rollover_alias =>{
                  'is_write_index' =>  true
              }
          }
      }
    end

    def policy_payload
      policy_path = ::File.expand_path(ILM_POLICY_PATH, ::File.dirname(__FILE__))
      LogStash::Json.load(::IO.read(policy_path))
    end
  end
end; end; end
