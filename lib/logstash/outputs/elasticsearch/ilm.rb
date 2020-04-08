module LogStash; module Outputs; class ElasticSearch
  module Ilm

    ILM_POLICY_PATH = "default-ilm-policy.json"

    def setup_ilm
      return unless ilm_in_use?
        logger.warn("Overwriting supplied index #{@index} with rollover alias #{@ilm_rollover_alias}") unless default_index?(@index)
        @index = @ilm_rollover_alias
        maybe_create_rollover_alias
        maybe_create_ilm_policy
    end

    def default_rollover_alias?(rollover_alias)
      rollover_alias == LogStash::Outputs::ElasticSearch::DEFAULT_ROLLOVER_ALIAS
    end

    def ilm_alias_set?
      default_index?(@index) || !default_rollover_alias?(@ilm_rollover_alias)
    end

    def ilm_in_use?
      return @ilm_actually_enabled if defined?(@ilm_actually_enabled)
      @ilm_actually_enabled =
        begin
          if @ilm_enabled == 'auto'
            if ilm_on_by_default?
              ilm_ready, error = ilm_ready?
              if !ilm_ready
                @logger.info("Index Lifecycle Management is set to 'auto', but will be disabled - #{error}")
                false
              else
                ilm_alias_set?
              end
            else
              @logger.info("Index Lifecycle Management is set to 'auto', but will be disabled - Your Elasticsearch cluster is before 7.0.0, which is the minimum version required to automatically run Index Lifecycle Management")
              false
            end
          elsif @ilm_enabled.to_s == 'true'
            ilm_ready, error = ilm_ready?
            raise LogStash::ConfigurationError,"Index Lifecycle Management is set to enabled in Logstash, but cannot be used - #{error}"  unless ilm_ready
            ilm_alias_set?
          else
            false
          end
        end
    end

    def ilm_on_by_default?
      maximum_seen_major_version >= 7
    end

    def ilm_ready?
      # Check the Elasticsearch instance for ILM readiness - this means that the version has to be a non-OSS release, with ILM feature
      # available and enabled.
      begin
        xpack = client.get_xpack_info
        features = xpack.nil? || xpack.empty? ? nil : xpack["features"]
        ilm = features.nil? ? nil : features["ilm"]
        return false, "Index Lifecycle management is not installed on your Elasticsearch cluster" if features.nil? || ilm.nil?
        return false, "Index Lifecycle management is not available in your Elasticsearch cluster" unless ilm['available']
        return false, "Index Lifecycle management is not enabled in your Elasticsearch cluster" unless ilm['enabled']
        return true, nil
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        # Check xpack endpoint: If no xpack endpoint, then this version of Elasticsearch is not compatible
        if e.response_code == 404
          return false, "Index Lifecycle management is not installed on your Elasticsearch cluster"
        elsif e.response_code == 400
          return false, "Index Lifecycle management is not installed on your Elasticsearch cluster"
        else
          raise e
        end
      end
    end

    private

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

    class ImproperAliasName < StandardError
      attr_reader :name
      def initialize(msg="Index not proper", name)
        @name = name
        super(msg)
      end
    end

    def maybe_create_rollover_alias_for_event(event, created_aliases, is_ilm_request)
      alias_name = event.sprintf(ilm_event_alias)
      return alias_name, created_aliases[alias_name] if created_aliases.has_key?(alias_name)
      improper = alias_name == ilm_event_alias
      alias_name = improper ? ilm_rollover_alias : alias_name
      alias_target = "<#{alias_name}-#{ilm_pattern}>"
      alias_payload = {
        'aliases' => {
          alias_name => {
            'is_write_index' => true
          }
        }
      }
      # Without placing the settings on the index you'll need something to run by and add this
      # afterwards (or by a template) or the first index will never rollover.
      do_ilm_request = is_ilm_request ? ilm_set_rollover_alias : false
      logger.trace("Putting rollover alias #{alias_target} for #{alias_name}, is this an ILM request?: #{is_ilm_request}, will we set the rollover alias setting? #{do_ilm_request}")
      client.rollover_alias_put(alias_target, alias_payload, do_ilm_request) unless client.rollover_alias_exists?(alias_name)

      # Raise this afterwards, so we can store this properly as a broken alias
      raise ImproperAliasName.new(name=event.sprintf(ilm_event_alias)) if improper

      return alias_name, alias_name
    end

    def maybe_create_rollover_alias
      client.rollover_alias_put(rollover_alias_target, rollover_alias_payload, ilm_set_rollover_alias) unless client.rollover_alias_exists?(ilm_rollover_alias)
    end

    def rollover_alias_target
      "<#{ilm_rollover_alias}-#{ilm_pattern}>"
    end

    def rollover_alias_payload
      {
          'aliases' => {
              ilm_rollover_alias => {
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
 end end end
