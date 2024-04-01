# encoding: utf-8
require "logstash/namespace"
require "logstash/environment"
require "logstash/outputs/base"
require "logstash/json"
require "concurrent/atomic/atomic_boolean"
require "stud/interval"
require "socket" # for Socket.gethostname
require "thread" # for safe queueing
require "uri" # for escaping user input
require "forwardable"
require "set"

# .Compatibility Note
# [NOTE]
# ================================================================================
# Starting with Elasticsearch 5.3, there's an {ref}modules-http.html[HTTP setting]
# called `http.content_type.required`. If this option is set to `true`, and you
# are using Logstash 2.4 through 5.2, you need to update the Elasticsearch output
# plugin to version 6.2.5 or higher.
#
# ================================================================================
#
# This plugin is the recommended method of storing logs in Elasticsearch.
# If you plan on using the Kibana web interface, you'll want to use this output.
#
# This output only speaks the HTTP protocol. HTTP is the preferred protocol for interacting with Elasticsearch as of Logstash 2.0.
# We strongly encourage the use of HTTP over the node protocol for a number of reasons. HTTP is only marginally slower,
# yet far easier to administer and work with. When using the HTTP protocol one may upgrade Elasticsearch versions without having
# to upgrade Logstash in lock-step.
#
# You can learn more about Elasticsearch at <https://www.elastic.co/products/elasticsearch>
#
# ==== Template management for Elasticsearch 5.x
# Index template for this version (Logstash 5.0) has been changed to reflect Elasticsearch's mapping changes in version 5.0.
# Most importantly, the subfield for string multi-fields has changed from `.raw` to `.keyword` to match ES default
# behavior.
#
# ** Users installing ES 5.x and LS 5.x **
# This change will not affect you and you will continue to use the ES defaults.
#
# ** Users upgrading from LS 2.x to LS 5.x with ES 5.x **
# LS will not force upgrade the template, if `logstash` template already exists. This means you will still use
# `.raw` for sub-fields coming from 2.x. If you choose to use the new template, you will have to reindex your data after
# the new template is installed.
#
# ==== Retry Policy
#
# The retry policy has changed significantly in the 2.2.0 release.
# This plugin uses the Elasticsearch bulk API to optimize its imports into Elasticsearch. These requests may experience
# either partial or total failures.
#
# The following errors are retried infinitely:
#
# - Network errors (inability to connect)
# - 429 (Too many requests) and
# - 503 (Service unavailable) errors
#
# NOTE: 409 exceptions are no longer retried. Please set a higher `retry_on_conflict` value if you experience 409 exceptions.
# It is more performant for Elasticsearch to retry these exceptions than this plugin.
#
# ==== Batch Sizes ====
# This plugin attempts to send batches of events as a single request. However, if
# a request exceeds 20MB we will break it up until multiple batch requests. If a single document exceeds 20MB it will be sent as a single request.
#
# ==== DNS Caching
#
# This plugin uses the JVM to lookup DNS entries and is subject to the value of https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html[networkaddress.cache.ttl],
# a global setting for the JVM.
#
# As an example, to set your DNS TTL to 1 second you would set
# the `LS_JAVA_OPTS` environment variable to `-Dnetworkaddress.cache.ttl=1`.
#
# Keep in mind that a connection with keepalive enabled will
# not reevaluate its DNS value while the keepalive is in effect.
#
# ==== HTTP Compression
#
# This plugin supports request and response compression. Response compression is enabled by default and 
# for Elasticsearch versions 5.0 and later, the user doesn't have to set any configs in Elasticsearch for 
# it to send back compressed response. For versions before 5.0, `http.compression` must be set to `true` in 
# Elasticsearch[https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http] to take advantage of response compression when using this plugin
#
# For requests compression, regardless of the Elasticsearch version, users have to enable `http_compression` 
# setting in their Logstash config file.
#
class LogStash::Outputs::ElasticSearch < LogStash::Outputs::Base
  declare_threadsafe!

  require "logstash/outputs/elasticsearch/license_checker"
  require "logstash/outputs/elasticsearch/http_client"
  require "logstash/outputs/elasticsearch/http_client_builder"
  require "logstash/plugin_mixins/elasticsearch/api_configs"
  require "logstash/plugin_mixins/elasticsearch/common"
  require "logstash/outputs/elasticsearch/ilm"
  require "logstash/outputs/elasticsearch/data_stream_support"
  require 'logstash/plugin_mixins/ecs_compatibility_support'
  require 'logstash/plugin_mixins/deprecation_logger_support'
  require 'logstash/plugin_mixins/normalize_config_support'

  # Protocol agnostic methods
  include(LogStash::PluginMixins::ElasticSearch::Common)

  # Config normalization helpers
  include(LogStash::PluginMixins::NormalizeConfigSupport)

  # Methods for ILM support
  include(LogStash::Outputs::ElasticSearch::Ilm)

  # ecs_compatibility option, provided by Logstash core or the support adapter.
  include(LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1, :v8))

  # deprecation logger adapter for older Logstashes
  include(LogStash::PluginMixins::DeprecationLoggerSupport)

  # Generic/API config options that any document indexer output needs
  include(LogStash::PluginMixins::ElasticSearch::APIConfigs)

  # DS support
  include(LogStash::Outputs::ElasticSearch::DataStreamSupport)

  DEFAULT_POLICY = "logstash-policy"

  config_name "elasticsearch"

  # The Elasticsearch action to perform. Valid actions are:
  #
  # - index: indexes a document (an event from Logstash).
  # - delete: deletes a document by id (An id is required for this action)
  # - create: indexes a document, fails if a document by that id already exists in the index.
  # - update: updates a document by id. Update has a special case where you can upsert -- update a
  #   document if not already present. See the `upsert` option. NOTE: This does not work and is not supported
  #   in Elasticsearch 1.x. Please upgrade to ES 2.x or greater to use this feature with Logstash!
  # - A sprintf style string to change the action based on the content of the event. The value `%{[foo]}`
  #   would use the foo field for the action
  #
  # For more details on actions, check out the http://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html[Elasticsearch bulk API documentation]
  config :action, :validate => :string # :default => "index" unless data_stream

  # The index to write events to. This can be dynamic using the `%{foo}` syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  # Indexes may not contain uppercase characters.
  # For weekly indexes ISO 8601 format is recommended, eg. logstash-%{+xxxx.ww}.
  # LS uses Joda to format the index pattern from event timestamp.
  # Joda formats are defined http://www.joda.org/joda-time/apidocs/org/joda/time/format/DateTimeFormat.html[here].
  config :index, :validate => :string

  config :document_type,
    :validate => :string,
    :deprecated => "Document types are being deprecated in Elasticsearch 6.0, and removed entirely in 7.0. You should avoid this feature"

  # From Logstash 1.3 onwards, a template is applied to Elasticsearch during
  # Logstash's startup if one with the name `template_name` does not already exist.
  # By default, the contents of this template is the default template for
  # `logstash-%{+YYYY.MM.dd}` which always matches indices based on the pattern
  # `logstash-*`.  Should you require support for other index names, or would like
  # to change the mappings in the template in general, a custom template can be
  # specified by setting `template` to the path of a template file.
  #
  # Setting `manage_template` to false disables this feature.  If you require more
  # control over template creation, (e.g. creating indices dynamically based on
  # field names) you should set `manage_template` to false and use the REST
  # API to apply your templates manually.
  #
  # Default value is `true` unless data streams is enabled
  config :manage_template, :validate => :boolean, :default => true

  # This configuration option defines how the template is named inside Elasticsearch.
  # Note that if you have used the template management features and subsequently
  # change this, you will need to prune the old template manually, e.g.
  #
  # `curl -XDELETE <http://localhost:9200/_template/OldTemplateName?pretty>`
  #
  # where `OldTemplateName` is whatever the former setting was.
  config :template_name, :validate => :string

  # You can set the path to your own template here, if you so desire.
  # If not set, the included template will be used.
  config :template, :validate => :path

  # The template_overwrite option will always overwrite the indicated template
  # in Elasticsearch with either the one indicated by template or the included one.
  # This option is set to false by default. If you always want to stay up to date
  # with the template provided by Logstash, this option could be very useful to you.
  # Likewise, if you have your own template file managed by puppet, for example, and
  # you wanted to be able to update it regularly, this option could help there as well.
  #
  # Please note that if you are using your own customized version of the Logstash
  # template (logstash), setting this to true will make Logstash to overwrite
  # the "logstash" template (i.e. removing all customized settings)
  config :template_overwrite, :validate => :boolean, :default => false

  # Flag for enabling legacy template api for Elasticsearch 8
  # Default auto will use index template api for Elasticsearch 8 and use legacy api for 7
  # Set to legacy to use legacy template api
  config :template_api, :validate => ['auto', 'legacy', 'composable'], :default => 'auto'

  # The version to use for indexing. Use sprintf syntax like `%{my_version}` to use a field value here.
  # See https://www.elastic.co/blog/elasticsearch-versioning-support.
  config :version, :validate => :string

  # The version_type to use for indexing.
  # See https://www.elastic.co/blog/elasticsearch-versioning-support.
  # See also https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-index_.html#_version_types
  config :version_type, :validate => ["internal", 'external', "external_gt", "external_gte", "force"]

  # A routing override to be applied to all processed events.
  # This can be dynamic using the `%{foo}` syntax.
  config :routing, :validate => :string

  # For child documents, ID of the associated parent.
  # This can be dynamic using the `%{foo}` syntax.
  config :parent, :validate => :string, :default => nil

  # For child documents, name of the join field
  config :join_field, :validate => :string, :default => nil

  # Set upsert content for update mode.s
  # Create a new document with this parameter as json string if `document_id` doesn't exists
  config :upsert, :validate => :string, :default => ""

  # Enable `doc_as_upsert` for update mode.
  # Create a new document with source if `document_id` doesn't exist in Elasticsearch
  config :doc_as_upsert, :validate => :boolean, :default => false

  # Set script name for scripted update mode
  config :script, :validate => :string, :default => ""

  # Define the type of script referenced by "script" variable
  #  inline : "script" contains inline script
  #  indexed : "script" contains the name of script directly indexed in elasticsearch
  #  file    : "script" contains the name of script stored in elasticseach's config directory
  config :script_type, :validate => ["inline", 'indexed', "file"], :default => ["inline"]

  # Set the language of the used script. If not set, this defaults to painless in ES 5.0
  config :script_lang, :validate => :string, :default => "painless"

  # Set variable name passed to script (scripted update)
  config :script_var_name, :validate => :string, :default => "event"

  # if enabled, script is in charge of creating non-existent document (scripted update)
  config :scripted_upsert, :validate => :boolean, :default => false

  # The number of times Elasticsearch should internally retry an update/upserted document
  # See the https://www.elastic.co/guide/en/elasticsearch/guide/current/partial-updates.html[partial updates]
  # for more info
  config :retry_on_conflict, :validate => :number, :default => 1

  # Set which ingest pipeline you wish to execute for an event. You can also use event dependent configuration
  # here like `pipeline => "%{INGEST_PIPELINE}"`
  config :pipeline, :validate => :string, :default => nil

  # -----
  # ILM configurations (beta)
  # -----
  # Flag for enabling Index Lifecycle Management integration.
  config :ilm_enabled, :validate => [true, false, 'true', 'false', 'auto'], :default => 'auto'

  # Rollover alias used for indexing data. If rollover alias doesn't exist, Logstash will create it and map it to the relevant index
  config :ilm_rollover_alias, :validate => :string

  # appends “{now/d}-000001” by default for new index creation, subsequent rollover indices will increment based on this pattern i.e. “000002”
  # {now/d} is date math, and will insert the appropriate value automatically.
  config :ilm_pattern, :validate => :string, :default => '{now/d}-000001'

  # ILM policy to use, if undefined the default policy will be used.
  config :ilm_policy, :validate => :string, :default => DEFAULT_POLICY

  attr_reader :client
  attr_reader :default_index
  attr_reader :default_ilm_rollover_alias
  attr_reader :default_template_name

  def initialize(*params)
    super
    setup_ecs_compatibility_related_defaults
    setup_ssl_params!
    setup_compression_level!
  end

  def register
    if !failure_type_logging_whitelist.empty?
      log_message = "'failure_type_logging_whitelist' is deprecated and in a future version of Elasticsearch " +
        "output plugin will be removed, please use 'silence_errors_in_log' instead."
      @deprecation_logger.deprecated log_message
      @logger.warn log_message
      @silence_errors_in_log = silence_errors_in_log | failure_type_logging_whitelist
    end

    @after_successful_connection_done = Concurrent::AtomicBoolean.new(false)
    @stopping = Concurrent::AtomicBoolean.new(false)

    check_action_validity

    @logger.info("New Elasticsearch output", :class => self.class.name, :hosts => @hosts.map(&:sanitized).map(&:to_s))

    # the license_checking behaviour in the Pool class is externalized in the LogStash::ElasticSearchOutputLicenseChecker
    # class defined in license_check.rb. This license checking is specific to the elasticsearch output here and passed
    # to build_client down to the Pool class.
    @client = build_client(LicenseChecker.new(@logger))

    # Avoids race conditions in the @data_stream_config initialization (invoking check_data_stream_config! twice).
    # It's being concurrently invoked by this register method and by the finish_register on the @after_successful_connection_thread
    data_stream_enabled = data_stream_config?

    setup_template_manager_defaults(data_stream_enabled)
    # To support BWC, we check if DLQ exists in core (< 5.4). If it doesn't, we use nil to resort to previous behavior.
    @dlq_writer = dlq_enabled? ? execution_context.dlq_writer : nil

    @dlq_codes = DOC_DLQ_CODES.to_set

    if dlq_enabled?
      check_dlq_custom_codes
      @dlq_codes.merge(dlq_custom_codes)
    else
      raise LogStash::ConfigurationError, "DLQ feature (dlq_custom_codes) is configured while DLQ is not enabled" unless dlq_custom_codes.empty?
    end

    setup_mapper_and_target(data_stream_enabled)

    @bulk_request_metrics = metric.namespace(:bulk_requests)
    @document_level_metrics = metric.namespace(:documents)

    @shutdown_from_finish_register = Concurrent::AtomicBoolean.new(false)
    @after_successful_connection_thread = after_successful_connection do
      begin
        finish_register
        true # thread.value
      rescue LogStash::ConfigurationError, LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        return e if pipeline_shutdown_requested?

        # retry when 429
        @logger.debug("Received a 429 status code during registration. Retrying..") && retry if too_many_requests?(e)

        # shut down pipeline
        if execution_context&.agent.respond_to?(:stop_pipeline)
          details = { message: e.message, exception: e.class }
          details[:backtrace] = e.backtrace if @logger.debug?
          @logger.error("Failed to bootstrap. Pipeline \"#{execution_context.pipeline_id}\" is going to shut down", details)

          @shutdown_from_finish_register.make_true
          execution_context.agent.stop_pipeline(execution_context.pipeline_id)
        end

        e
      rescue => e
        e # thread.value
      ensure
        @after_successful_connection_done.make_true
      end
    end

  end

  def setup_mapper_and_target(data_stream_enabled)
    if data_stream_enabled
      @event_mapper = -> (e) { data_stream_event_action_tuple(e) }
      @event_target = -> (e) { data_stream_name(e) }
      @index = "#{data_stream_type}-#{data_stream_dataset}-#{data_stream_namespace}".freeze # default name
    else
      @event_mapper = -> (e) { event_action_tuple(e) }
      @event_target = -> (e) { e.sprintf(@index) }
    end
  end

  # @override post-register when ES connection established
  def finish_register
    assert_es_version_supports_data_streams if data_stream_config?
    discover_cluster_uuid
    install_template
    setup_ilm if ilm_in_use?
    super
  end

  # @override to handle proxy => '' as if none was set
  def config_init(params)
    proxy = params['proxy']
    if proxy.is_a?(String)
      # environment variables references aren't yet resolved
      proxy = deep_replace(proxy)
      if proxy.empty?
        params.delete('proxy')
        @proxy = ''
      else
        params['proxy'] = proxy # do not do resolving again
      end
    end

    super(params)
  end

  # Receive an array of events and immediately attempt to index them (no buffering)
  def multi_receive(events)
    wait_for_successful_connection if @after_successful_connection_done
    events_mapped = safe_interpolation_map_events(events)
    retrying_submit(events_mapped.successful_events)
    unless events_mapped.event_mapping_errors.empty?
      handle_event_mapping_errors(events_mapped.event_mapping_errors)
    end
  end

  # @param: Arrays of FailedEventMapping
  private
  def handle_event_mapping_errors(event_mapping_errors)
    # if DQL is enabled, log the events to provide issue insights to users.
    if @dlq_writer
      @logger.warn("Events could not be indexed and routing to DLQ, count: #{event_mapping_errors.size}")
    end

    event_mapping_errors.each do |event_mapping_error|
      detailed_message = "#{event_mapping_error.message}; event: `#{event_mapping_error.event.to_hash_with_metadata}`"
      @dlq_writer ? @dlq_writer.write(event_mapping_error.event, detailed_message) : @logger.warn(detailed_message)
    end
    @document_level_metrics.increment(:non_retryable_failures, event_mapping_errors.size)
  end

  MapEventsResult = Struct.new(:successful_events, :event_mapping_errors)
  FailedEventMapping = Struct.new(:event, :message)

  private
  def safe_interpolation_map_events(events)
    successful_events = [] # list of LogStash::Outputs::ElasticSearch::EventActionTuple
    event_mapping_errors = [] # list of FailedEventMapping
    events.each do |event|
      begin
        successful_events << @event_mapper.call(event)
      rescue EventMappingError => ie
        event_mapping_errors << FailedEventMapping.new(event, ie.message)
      end
    end
    MapEventsResult.new(successful_events, event_mapping_errors)
  end

  public
  def map_events(events)
    safe_interpolation_map_events(events).successful_events
  end

  def wait_for_successful_connection
    after_successful_connection_done = @after_successful_connection_done
    return unless after_successful_connection_done
    stoppable_sleep 1 until (after_successful_connection_done.true? || pipeline_shutdown_requested?)

    if pipeline_shutdown_requested? && !after_successful_connection_done.true?
      logger.info "Aborting the batch due to shutdown request while waiting for connections to become live"
      abort_batch_if_available!
    end

    status = @after_successful_connection_thread && @after_successful_connection_thread.value
    if status.is_a?(Exception) # check if thread 'halted' with an error
      # keep logging that something isn't right (from every #multi_receive)
      @logger.error "Elasticsearch setup did not complete normally, please review previously logged errors",
                    message: status.message, exception: status.class
    else
      @after_successful_connection_done = nil # do not execute __method__ again if all went well
    end
  end
  private :wait_for_successful_connection

  def close
    @stopping.make_true if @stopping
    stop_after_successful_connection_thread
    @client.close if @client
  end

  private

  def stop_after_successful_connection_thread
    # avoid deadlock when finish_register calling execution_context.agent.stop_pipeline
    # stop_pipeline triggers plugin close and the plugin close waits for after_successful_connection_thread to join
    return if @shutdown_from_finish_register&.true?

    @after_successful_connection_thread.join if @after_successful_connection_thread&.alive?
  end

  # Convert the event into a 3-tuple of action, params and event hash
  def event_action_tuple(event)
    params = common_event_params(event)
    params[:_type] = get_event_type(event) if use_event_type?(nil)

    if @parent
      if @join_field
        join_value = event.get(@join_field)
        parent_value = event.sprintf(@parent)
        event.set(@join_field, { "name" => join_value, "parent" => parent_value })
        params[routing_field_name] = event.sprintf(@parent)
      else
        params[:parent] = event.sprintf(@parent)
      end
    end

    action = event.sprintf(@action || 'index')
    raise UnsupportedActionError, action unless VALID_HTTP_ACTIONS.include?(action)

    if action == 'update'
      params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @upsert != ""
      params[:_script] = event.sprintf(@script) if @script != ""
      params[retry_on_conflict_action_name] = @retry_on_conflict
    end

    event_control = event.get("[@metadata][_ingest_document]")
    event_version, event_version_type = event_control&.values_at("version", "version_type") rescue nil

    resolved_version = resolve_version(event, event_version)
    resolved_version_type = resolve_version_type(event, event_version_type)

    # avoid to add nil valued key-value pairs
    params[:version] = resolved_version unless resolved_version.nil?
    params[:version_type] = resolved_version_type unless resolved_version_type.nil?

    EventActionTuple.new(action, params, event)
  end

  class EventActionTuple < Array # TODO: acting as an array for compatibility

    def initialize(action, params, event, event_data = nil)
      super(3)
      self[0] = action
      self[1] = params
      self[2] = event_data || event.to_hash
      @event = event
    end

    attr_reader :event

  end

  class EventMappingError < ArgumentError
    def initialize(msg = nil)
      super
    end
  end

  class IndexInterpolationError < EventMappingError
    def initialize(bad_formatted_index)
      super("Badly formatted index, after interpolation still contains placeholder: [#{bad_formatted_index}]")
    end
  end

  class UnsupportedActionError < EventMappingError
    def initialize(bad_action)
      super("Elasticsearch doesn't support [#{bad_action}] action")
    end
  end

  # @return Hash (initial) parameters for given event
  # @private shared event params factory between index and data_stream mode
  def common_event_params(event)
    event_control = event.get("[@metadata][_ingest_document]")
    event_id, event_pipeline, event_index, event_routing = event_control&.values_at("id","pipeline","index", "routing") rescue nil

    params = {
        :_id => resolve_document_id(event, event_id),
        :_index => resolve_index!(event, event_index),
        routing_field_name => resolve_routing(event, event_routing)
    }

    target_pipeline = resolve_pipeline(event, event_pipeline)
    # convention: empty string equates to not using a pipeline
    # this is useful when using a field reference in the pipeline setting, e.g.
    #      elasticsearch {
    #        pipeline => "%{[@metadata][pipeline]}"
    #      }
    params[:pipeline] = target_pipeline unless (target_pipeline.nil? || target_pipeline.empty?)

    params
  end

  def resolve_version(event, event_version)
    return event_version if event_version && !@version
    event.sprintf(@version) if @version
  end
  private :resolve_version

  def resolve_version_type(event, event_version_type)
    return event_version_type if event_version_type && !@version_type
    event.sprintf(@version_type) if @version_type
  end
  private :resolve_version_type

  def resolve_routing(event, event_routing)
    return event_routing if event_routing && !@routing
    @routing ? event.sprintf(@routing) : nil
  end
  private :resolve_routing

  def resolve_document_id(event, event_id)
    return event.sprintf(@document_id) if @document_id
    return event_id || nil
  end
  private :resolve_document_id

  def resolve_index!(event, event_index)
    sprintf_index = @event_target.call(event)
    raise IndexInterpolationError, sprintf_index if sprintf_index.match(/%{.*?}/) && dlq_on_failed_indexname_interpolation
    # if it's not a data stream, sprintf_index is the @index with resolved placeholders.
    # if is a data stream, sprintf_index could be either the name of a data stream or the value contained in
    # @index without placeholders substitution. If event's metadata index is provided, it takes precedence
    # on datastream name or whatever is returned by the event_target provider.
    return event_index if @index == @default_index && event_index
    return sprintf_index
  end
  private :resolve_index!

  def resolve_pipeline(event, event_pipeline)
    return event_pipeline if event_pipeline && !@pipeline
    pipeline_template = @pipeline || event.get("[@metadata][target_ingest_pipeline]")&.to_s
    pipeline_template && event.sprintf(pipeline_template)
  end

  @@plugins = Gem::Specification.find_all{|spec| spec.name =~ /logstash-output-elasticsearch-/ }

  @@plugins.each do |plugin|
    name = plugin.name.split('-')[-1]
    require "logstash/outputs/elasticsearch/#{name}"
  end

  def retry_on_conflict_action_name
    maximum_seen_major_version >= 7 ? :retry_on_conflict : :_retry_on_conflict
  end

  def routing_field_name
    :routing
  end

  # Determine the correct value for the 'type' field for the given event
  DEFAULT_EVENT_TYPE_ES6 = "doc".freeze
  DEFAULT_EVENT_TYPE_ES7 = "_doc".freeze

  def get_event_type(event)
    # Set the 'type' value for the index.
    type = if @document_type
             event.sprintf(@document_type)
           else
             major_version = maximum_seen_major_version
             if major_version == 6
               DEFAULT_EVENT_TYPE_ES6
             elsif major_version == 7
               DEFAULT_EVENT_TYPE_ES7
             else
               nil
             end
           end

    type.to_s
  end

  ##
  # WARNING: This method is overridden in a subclass in Logstash Core 7.7-7.8's monitoring,
  #          where a `client` argument is both required and ignored. In later versions of
  #          Logstash Core it is optional and ignored, but to make it optional here would
  #          allow us to accidentally break compatibility with Logstashes where it was required.
  # @param noop_required_client [nil]: required `nil` for legacy reasons.
  # @return [Boolean]
  def use_event_type?(noop_required_client)
    # always set type for ES 6
    # for ES 7 only set it if the user defined it
    (maximum_seen_major_version < 7) || (maximum_seen_major_version == 7 && @document_type)
  end

  def install_template
    TemplateManager.install_template(self)
  rescue => e
    details = { message: e.message, exception: e.class, backtrace: e.backtrace }
    details[:body] = e.response_body if e.respond_to?(:response_body)
    @logger.error("Failed to install template", details)
    raise e if register_termination_error?(e)
  end

  def setup_ecs_compatibility_related_defaults
    case ecs_compatibility
    when :disabled
      @default_index = "logstash-%{+yyyy.MM.dd}"
      @default_ilm_rollover_alias = "logstash"
      @default_template_name = 'logstash'
    when :v1, :v8
      @default_index = "ecs-logstash-%{+yyyy.MM.dd}"
      @default_ilm_rollover_alias = "ecs-logstash"
      @default_template_name = 'ecs-logstash'
    else
      fail("unsupported ECS Compatibility `#{ecs_compatibility}`")
    end

    @index ||= default_index
    @ilm_rollover_alias ||= default_ilm_rollover_alias
    @template_name ||= default_template_name
  end

  def setup_template_manager_defaults(data_stream_enabled)
    if original_params["manage_template"].nil? && data_stream_enabled
      logger.debug("Disabling template management since data streams are enabled")
      @manage_template = false
    end
  end

  def setup_ssl_params!
    @ssl_enabled = normalize_config(:ssl_enabled) do |normalize|
      normalize.with_deprecated_alias(:ssl)
    end

    @ssl_certificate_authorities = normalize_config(:ssl_certificate_authorities) do |normalize|
      normalize.with_deprecated_mapping(:cacert) do |cacert|
        [cacert]
      end
    end

    @ssl_keystore_path =  normalize_config(:ssl_keystore_path) do |normalize|
      normalize.with_deprecated_alias(:keystore)
    end

    @ssl_keystore_password = normalize_config(:ssl_keystore_password) do |normalize|
      normalize.with_deprecated_alias(:keystore_password)
    end

    @ssl_truststore_path = normalize_config(:ssl_truststore_path) do |normalize|
      normalize.with_deprecated_alias(:truststore)
    end

    @ssl_truststore_password =  normalize_config(:ssl_truststore_password) do |normalize|
      normalize.with_deprecated_alias(:truststore_password)
    end

    @ssl_verification_mode = normalize_config(:ssl_verification_mode) do |normalize|
      normalize.with_deprecated_mapping(:ssl_certificate_verification) do |ssl_certificate_verification|
        if ssl_certificate_verification == true
          "full"
        else
          "none"
        end
      end
    end

    params['ssl_enabled'] = @ssl_enabled unless @ssl_enabled.nil?
    params['ssl_certificate_authorities'] = @ssl_certificate_authorities unless @ssl_certificate_authorities.nil?
    params['ssl_keystore_path'] = @ssl_keystore_path unless @ssl_keystore_path.nil?
    params['ssl_keystore_password'] = @ssl_keystore_password unless @ssl_keystore_password.nil?
    params['ssl_truststore_path'] = @ssl_truststore_path unless @ssl_truststore_path.nil?
    params['ssl_truststore_password'] = @ssl_truststore_password unless @ssl_truststore_password.nil?
    params['ssl_verification_mode'] = @ssl_verification_mode unless @ssl_verification_mode.nil?
  end

  def setup_compression_level!
    @compression_level = normalize_config(:compression_level) do |normalize|
      normalize.with_deprecated_mapping(:http_compression) do |http_compression|
        if http_compression == true
          DEFAULT_ZIP_LEVEL
        else
          0
        end
      end
    end

    params['compression_level'] = @compression_level unless @compression_level.nil?
  end

  # To be overidden by the -java version
  VALID_HTTP_ACTIONS = ["index", "delete", "create", "update"]
  def valid_actions
    VALID_HTTP_ACTIONS
  end

  def check_action_validity
    return if @action.nil? # not set
    raise LogStash::ConfigurationError, "No action specified!" if @action.empty?

    # If we're using string interpolation, we're good!
    return if @action =~ /%{.+}/
    return if valid_actions.include?(@action)

    raise LogStash::ConfigurationError, "Action '#{@action}' is invalid! Pick one of #{valid_actions} or use a sprintf style statement"
  end

  def check_dlq_custom_codes
    intersection = dlq_custom_codes & DOC_DLQ_CODES
    raise LogStash::ConfigurationError, "#{intersection} are already defined as standard DLQ error codes" unless intersection.empty?

    intersection = dlq_custom_codes & DOC_SUCCESS_CODES
    raise LogStash::ConfigurationError, "#{intersection} are success codes which cannot be redefined in dlq_custom_codes" unless intersection.empty?

    intersection = dlq_custom_codes & [DOC_CONFLICT_CODE]
    raise LogStash::ConfigurationError, "#{intersection} are error codes already defined as conflict which cannot be redefined in dlq_custom_codes" unless intersection.empty?
  end
end
