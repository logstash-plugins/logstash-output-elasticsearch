module LogStash module Outputs class ElasticSearch
  # DS specific behavior/configuration.
  module DataStreamSupport

    def self.included(base)
      # Defines whether data will be indexed into an Elasticsearch data stream,
      # `data_stream_*` settings will only be used if this setting is enabled!
      # This setting supports values `true`, `false`, and `auto`.
      # Defaults to `false` in Logstash 7.x and `auto` starting in Logstash 8.0.
      base.config :data_stream, :validate => ['true', 'false', 'auto']

      base.config :data_stream_type, :validate => ['logs', 'metrics', 'synthetics'], :default => 'logs'
      base.config :data_stream_dataset, :validate => :dataset_identifier, :default => 'generic'
      base.config :data_stream_namespace, :validate => :namespace_identifier, :default => 'default'

      base.config :data_stream_sync_fields, :validate => :boolean, :default => true
      base.config :data_stream_auto_routing, :validate => :boolean, :default => true

      base.extend(Validator)
    end

    # @override
    def finish_register
      super

      if data_stream_config?
        @event_mapper = -> (e) { data_stream_event_action_tuple(e) }
        @event_target = -> (e) { data_stream_name(e) }
        @index = "#{data_stream_type}-#{data_stream_dataset}-#{data_stream_namespace}".freeze # default name
      end
    end

    # @note assumes to be running AFTER {after_successful_connection} completed, due ES version checks
    def data_stream_config?
      @data_stream_config.nil? ? @data_stream_config = check_data_stream_config! : @data_stream_config
    end

    private

    def data_stream_name(event)
      data_stream = event.get('data_stream')
      return @index if !data_stream_auto_routing || !data_stream.is_a?(Hash)

      type = data_stream['type'] || data_stream_type
      dataset = data_stream['dataset'] || data_stream_dataset
      namespace = data_stream['namespace'] || data_stream_namespace
      "#{type}-#{dataset}-#{namespace}"
    end

    # @param params the user configuration for the ES output
    # @note LS initialized configuration (with filled defaults) won't detect as data-stream
    # compatible, only explicit (`original_params`) config should be tested.
    # @return [TrueClass|FalseClass] whether given configuration is data-stream compatible
    def check_data_stream_config!(params = original_params)
      use_data_stream = data_stream_explicit?
      data_stream_params = params.select { |name, _| name.start_with?('data_stream_') } # exclude data_stream =>
      invalid_data_stream_params = invalid_data_stream_params(params)

      if use_data_stream.eql?(false) && data_stream_params.any?
        @logger.warn "Ignoring data stream specific settings (due data_stream => false)", data_stream_params
      end

      if use_data_stream.nil?
        use_data_stream = data_stream_default(params, invalid_data_stream_params.empty?)
      end

      if use_data_stream
        if invalid_data_stream_params.any?
          @logger.error "Invalid data_stream configuration, following parameters are not supported:", invalid_data_stream_params
          raise LogStash::ConfigurationError, "invalid data stream configuration: #{invalid_data_stream_params.keys}"
        end
        true
      else
        false
      end
    end

    def data_stream_explicit?
      case @data_stream
      when 'true'
        assert_es_version_supports_data_streams
        return true
      when 'false'
        return false
      else
        return nil # 'auto' or not set by user
      end
    end

    def invalid_data_stream_params(params)
      shared_params = LogStash::PluginMixins::ElasticSearch::APIConfigs::CONFIG_PARAMS.keys.map(&:to_s)
      params.reject do |name, value|
        # NOTE: intentionally do not support explicit DS configuration like:
        # - `index => ...` identifier provided by data_stream_xxx settings
        # - `manage_template => false` implied by not setting the parameter
        case name
        when 'action'
          value == 'create'
        when 'routing', 'pipeline'
          true
        when 'data_stream'
          value.to_s == 'true'
        else
          name.start_with?('data_stream_') ||
              shared_params.include?(name) ||
                inherited_internal_config_param?(name) # 'id', 'enabled_metric' etc
        end
      end
    end

    def inherited_internal_config_param?(name)
      self.class.superclass.get_config.key?(name.to_s) # superclass -> LogStash::Outputs::Base
    end

    DATA_STREAMS_ORIGIN_ES_VERSION = '7.9.0'

    # @return [Gem::Version] if ES supports DS nil (or raise) otherwise
    def assert_es_version_supports_data_streams(raise_error = true)
      es_version = last_es_version_object
      if es_version < Gem::Version.create(DATA_STREAMS_ORIGIN_ES_VERSION)
        return nil unless raise_error
        @logger.info "Elasticsearch version does not support data streams", es_version: es_version.version
        raise LogStash::ConfigurationError, "data_stream is only supported since Elasticsearch #{DATA_STREAMS_ORIGIN_ES_VERSION} " +
                                            "(detected version #{es_version.version}), please upgrade your cluster"
      end
      es_version # return truthy
    end

    def last_es_version_object
      fail 'no last_es_version' unless last_es_version # assert - should not happen
      Gem::Version.create(last_es_version)
    end

    DATA_STREAMS_ENABLED_BY_DEFAULT_LS_VERSION = '8.0.0'

    # when data_stream => is either 'auto' or not set
    def data_stream_default(params, valid_data_stream_config)
      ds_default = Gem::Version.create(LOGSTASH_VERSION) >= Gem::Version.create(DATA_STREAMS_ENABLED_BY_DEFAULT_LS_VERSION)

      return false if @data_stream.nil? && !ds_default # data_stream => ... not set on LS 7.x

      if ds_default # LS 8.0
        return false unless valid_data_stream_config
        if LogStash::OSS
          if assert_es_version_supports_data_streams(false)
            @logger.warn "Configuration is data_stream compliant but won't be used (enable explicitly with data_stream => true)"
            return false
          end
        else
          assert_es_version_supports_data_streams(true)
        end
        return true
      end

      # LS 7.x data_stream => auto
      valid_data_stream_config && assert_es_version_supports_data_streams(false)
    end

    # an {event_action_tuple} replacement when a data-stream configuration is detected
    def data_stream_event_action_tuple(event)
      ['create', common_event_params(event), event.to_hash] # action always 'create'
    end

    module Validator

      # @override {LogStash::Config::Mixin::validate_value} to provide :ds_identifier_string validator
      # @param value [Array<Object>]
      # @param validator [nil,Array,Symbol]
      # @return [Array(true,Object)]: if validation is a success, a tuple containing `true` and the coerced value
      # @return [Array(false,String)]: if validation is a failure, a tuple containing `false` and the failure reason.
      def validate_value(value, validator)
        if validator == :dataset_identifier
          return validate_dataset_identifier(value, validator)
        end
        if validator == :namespace_identifier
          return validate_namespace_identifier(value, validator)
        end
        return super unless validator == :ds_identifier_string

        super(value, validator)
      end

      private

      def validate_dataset_identifier(value, validator)
        value = deep_replace(value)
        value = hash_or_array(value)

        # TODO
        # return true, value.first if value.size == 1 && value.first.empty?
        validate_value(value, :string)
      end

      def validate_namespace_identifier(value, validator)
        # TODO
        validate_value(value, :string)
      end

    end

  end
end end end