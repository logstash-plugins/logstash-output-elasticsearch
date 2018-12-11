module LogStash; module Outputs; class ElasticSearch
  module Ilm

    ILM_POLICY_PATH = "default-ilm-policy.json"

    def setup_ilm
      return unless ilm_enabled?
      @logger.info("Using Index lifecycle management - this feature is currently in beta.")
      @logger.warn "Overwriting supplied index name with rollover alias #{@ilm_rollover_alias}" if @index != LogStash::Outputs::ElasticSearch::CommonConfigs::DEFAULT_INDEX_NAME
      @index = ilm_rollover_alias

      maybe_create_rollover_alias
      maybe_create_ilm_policy
    end

    def ilm_enabled?
      @ilm_enabled
    end

    def verify_ilm_readiness
      return unless ilm_enabled?

      # Check the Elasticsearch instance for ILM readiness - this means that the version has to be a non-OSS release, with ILM feature
      # available and enabled.
      begin
        xpack = client.get_xpack_info
        features = xpack["features"]
        ilm = features.nil? ? nil : features["ilm"]
        raise LogStash::ConfigurationError, "Index Lifecycle management is enabled in logstash, but not installed on your Elasticsearch cluster" if features.nil? || ilm.nil?
        raise LogStash::ConfigurationError, "Index Lifecycle management is enabled in logstash, but not available in your Elasticsearch cluster" unless ilm['available']
        raise LogStash::ConfigurationError, "Index Lifecycle management is enabled in logstash, but not enabled in your Elasticsearch cluster" unless ilm['enabled']

        unless ilm_policy_default? || client.ilm_policy_exists?(ilm_policy)
          raise LogStash::ConfigurationError, "The specified ILM policy #{ilm_policy} does not exist on your Elasticsearch instance"
        end

      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        # Check xpack endpoint: If no xpack endpoint, then this version of Elasticsearch is not compatible
        if e.response_code == 404
          raise LogStash::ConfigurationError, "Index Lifecycle management is enabled in logstash, but not installed on your Elasticsearch cluster"
        elsif e.response_code == 400
          raise LogStash::ConfigurationError, "Index Lifecycle management is enabled in logstash, but not installed on your Elasticsearch cluster"
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
      if ilm_policy_default? && !client.ilm_policy_exists?(ilm_policy)
        client.ilm_policy_put(ilm_policy, policy_payload)
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
 end end end