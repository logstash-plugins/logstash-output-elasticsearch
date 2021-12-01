module LogStash module Outputs class ElasticSearch
  # DS specific behavior/configuration.
  module DataStreamSupport

    # @api private
    ENABLING_ECS_GUIDANCE = <<~END.tr("\n", " ")
      Elasticsearch data streams require that events adhere to the Elastic Common Schema.
      While `ecs_compatibility` can be set for this individual Elasticsearch output plugin, doing so will not fix schema conflicts caused by upstream plugins in your pipeline.
      To avoid mapping conflicts, you will need to use ECS-compatible field names and datatypes throughout your pipeline.
      Many plugins support an `ecs_compatibility` mode, and the `pipeline.ecs_compatibility` setting can be used to opt-in for all plugins in a pipeline.
    END
    private_constant :ENABLING_ECS_GUIDANCE

    def self.included(base)
      # Defines whether data will be indexed into an Elasticsearch data stream,
      # `data_stream_*` settings will only be used if this setting is enabled!
      # This setting supports values `true`, `false`, and `auto`.
      # Defaults to `false` in Logstash 7.x and `auto` starting in Logstash 8.0.
      base.config :data_stream, :validate => ['true', 'false', 'auto']

      base.config :data_stream_type, :validate => ['logs', 'metrics', 'synthetics', 'traces'], :default => 'logs'
      base.config :data_stream_dataset, :validate => :dataset_identifier, :default => 'generic'
      base.config :data_stream_namespace, :validate => :namespace_identifier, :default => 'default'

      base.config :data_stream_sync_fields, :validate => :boolean, :default => true
      base.config :data_stream_auto_routing, :validate => :boolean, :default => true

      base.extend(Validator)
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

    DATA_STREAMS_REQUIRES_ECS_LS_VERSION = '8.0.0'

    # @param params the user configuration for the ES output
    # @note LS initialized configuration (with filled defaults) won't detect as data-stream
    # compatible, only explicit (`original_params`) config should be tested.
    # @return [TrueClass|FalseClass] whether given configuration is data-stream compatible
    def check_data_stream_config!(params = original_params)
      data_stream_params = params.select { |name, _| name.start_with?('data_stream_') } # exclude data_stream =>
      invalid_data_stream_params = invalid_data_stream_params(params)

      case data_stream_explicit_value
      when false
        if data_stream_params.any?
          @logger.error "Ambiguous configuration; data stream settings must not be present when data streams is disabled (caused by: `data_stream => false`)", data_stream_params
          raise LogStash::ConfigurationError, "Ambiguous configuration, please remove data stream specific settings: #{data_stream_params.keys}"
        end
        return false
      when true
        if invalid_data_stream_params.any?
          @logger.error "Invalid data stream configuration, following parameters are not supported:", invalid_data_stream_params
          raise LogStash::ConfigurationError, "Invalid data stream configuration: #{invalid_data_stream_params.keys}"
        end
        if ecs_compatibility == :disabled
          if ::Gem::Version.create(LOGSTASH_VERSION) < ::Gem::Version.create(DATA_STREAMS_REQUIRES_ECS_LS_VERSION)
            @deprecation_logger.deprecated "In a future release of Logstash, the Elasticsearch output plugin's `data_stream => true` will require the plugin to be run in ECS compatibility mode. " + ENABLING_ECS_GUIDANCE
          else
            @logger.error "Invalid data stream configuration; `ecs_compatibility` must not be `disabled`. " + ENABLING_ECS_GUIDANCE
            raise LogStash::ConfigurationError, "Invalid data stream configuration: `ecs_compatibility => disabled`"
          end
        end
        return true
      else
        use_data_stream = data_stream_default(data_stream_params, invalid_data_stream_params)
        if use_data_stream
          @logger.info("Config is compliant with data streams. `data_stream => auto` resolved to `true`")
        elsif data_stream_params.any?
          # DS (auto) disabled but there's still some data-stream parameters (and no `data_stream => false`)
          @logger.error "Ambiguous configuration; data stream settings are present, but data streams are not enabled", data_stream_params
          raise LogStash::ConfigurationError, "Ambiguous configuration, please set data_stream => true " +
              "or remove data stream specific settings: #{data_stream_params.keys}"
        else
          @logger.info("Config is not compliant with data streams. `data_stream => auto` resolved to `false`")
        end
        use_data_stream
      end
    end

    def data_stream_explicit_value
      case @data_stream
      when 'true'
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
        when 'ecs_compatibility' then true # required for LS <= 6.x
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
    def assert_es_version_supports_data_streams
      fail 'no last_es_version' unless last_es_version # assert - should not happen
      es_version = ::Gem::Version.create(last_es_version)
      if es_version < ::Gem::Version.create(DATA_STREAMS_ORIGIN_ES_VERSION)
        @logger.error "Elasticsearch version does not support data streams, Logstash might end up writing to an index", es_version: es_version.version
        # NOTE: when switching to synchronous check from register, this should be a ConfigurationError
        raise LogStash::Error, "A data_stream configuration is only supported since Elasticsearch #{DATA_STREAMS_ORIGIN_ES_VERSION} " +
                               "(detected version #{es_version.version}), please upgrade your cluster"
      end
      es_version # return truthy
    end

    DATA_STREAMS_ENABLED_BY_DEFAULT_LS_VERSION = '8.0.0'

    # when data_stream => is either 'auto' or not set
    # @param data_stream_params [#any?]
    # @param invalid_data_stream_config [#any?#inspect]
    def data_stream_default(data_stream_params, invalid_data_stream_config)
      if ecs_compatibility == :disabled
        @logger.debug("Not eligible for data streams because ecs_compatibility is not enabled. " + ENABLING_ECS_GUIDANCE)
        return false
      end

      ds_default = ::Gem::Version.create(LOGSTASH_VERSION) >= ::Gem::Version.create(DATA_STREAMS_ENABLED_BY_DEFAULT_LS_VERSION)

      if ds_default # LS 8.0
        if invalid_data_stream_config.any?
          @logger.debug("Not eligible for data streams because config contains one or more settings that are not compatible with data streams: #{invalid_data_stream_config.inspect}")
          return false
        end

        @logger.debug 'Configuration is data stream compliant'
        return true
      end

      # LS 7.x
      if !invalid_data_stream_config.any? && !data_stream_params.any?
        @logger.warn "Configuration is data stream compliant but due backwards compatibility Logstash 7.x will not assume " +
                     "writing to a data-stream, default behavior will change on Logstash 8.0 " +
                     "(set `data_stream => true/false` to disable this warning)"
      end
      false
    end

    # an {event_action_tuple} replacement when a data-stream configuration is detected
    def data_stream_event_action_tuple(event)
      event_data = event.to_hash
      data_stream_event_sync(event_data) if data_stream_sync_fields
      EventActionTuple.new('create', common_event_params(event), event, event_data)
    end

    DATA_STREAM_SYNC_FIELDS = [ 'type', 'dataset', 'namespace' ].freeze

    def data_stream_event_sync(event_data)
      data_stream = event_data['data_stream']
      if data_stream.is_a?(Hash)
        unless data_stream_auto_routing
          sync_fields = DATA_STREAM_SYNC_FIELDS.select { |name| data_stream.key?(name) && data_stream[name] != send(:"data_stream_#{name}") }
          if sync_fields.any? # these fields will need to be overwritten
            info = sync_fields.inject({}) { |info, name| info[name] = data_stream[name]; info }
            info[:event] = event_data
            @logger.warn "Some data_stream fields are out of sync, these will be updated to reflect data-stream name", info

            # NOTE: we work directly with event.to_hash data thus fine to mutate the 'data_stream' hash
            sync_fields.each { |name| data_stream[name] = nil } # fallback to ||= bellow
          end
        end
      else
        unless data_stream.nil?
          @logger.warn "Invalid 'data_stream' field type, due fields sync will overwrite", value: data_stream, event: event_data
        end
        event_data['data_stream'] = data_stream = Hash.new
      end

      data_stream['type'] ||= data_stream_type
      data_stream['dataset'] ||= data_stream_dataset
      data_stream['namespace'] ||= data_stream_namespace

      event_data
    end

    module Validator

      # @override {LogStash::Config::Mixin::validate_value} to handle custom validators
      # @param value [Array<Object>]
      # @param validator [nil,Array,Symbol]
      # @return [Array(true,Object)]: if validation is a success, a tuple containing `true` and the coerced value
      # @return [Array(false,String)]: if validation is a failure, a tuple containing `false` and the failure reason.
      def validate_value(value, validator)
        case validator
        when :dataset_identifier   then validate_dataset_identifier(value)
        when :namespace_identifier then validate_namespace_identifier(value)
        else super
        end
      end

      private

      def validate_dataset_identifier(value)
        valid, value = validate_value(value, :string)
        return false, value unless valid

        validate_identifier(value)
      end

      def validate_namespace_identifier(value)
        valid, value = validate_value(value, :string)
        return false, value unless valid

        validate_identifier(value)
      end

      def validate_identifier(value, max_size = 100)
        if value.empty?
          return false, "Invalid identifier - empty string"
        end
        if value.bytesize > max_size
          return false, "Invalid identifier - too long (#{value.bytesize} bytes)"
        end
        # cannot include \, /, *, ?, ", <, >, |, ' ' (space char), ',', #, :
        if value.match? Regexp.union(INVALID_IDENTIFIER_CHARS)
          return false, "Invalid characters detected #{INVALID_IDENTIFIER_CHARS.inspect} are not allowed"
        end
        return true, value
      end

      INVALID_IDENTIFIER_CHARS = [ '\\', '/', '*', '?', '"', '<', '>', '|', ' ', ',', '#', ':' ]
      private_constant :INVALID_IDENTIFIER_CHARS

    end

  end
end end end
