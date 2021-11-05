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

  # Protocol agnostic methods
  include(LogStash::PluginMixins::ElasticSearch::Common)

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
  end

  def register
    @after_successful_connection_done = Concurrent::AtomicBoolean.new(false)
    @stopping = Concurrent::AtomicBoolean.new(false)

    check_action_validity

    @logger.info("New Elasticsearch output", :class => self.class.name, :hosts => @hosts.map(&:sanitized).map(&:to_s))

    # the license_checking behaviour in the Pool class is externalized in the LogStash::ElasticSearchOutputLicenseChecker
    # class defined in license_check.rb. This license checking is specific to the elasticsearch output here and passed
    # to build_client down to the Pool class.
    @client = build_client(LicenseChecker.new(@logger))

    @after_successful_connection_thread = after_successful_connection do
      begin
        finish_register
        true # thread.value
      rescue => e
        # we do not want to halt the thread with an exception as that has consequences for LS
        e # thread.value
      ensure
        @after_successful_connection_done.make_true
      end
    end

    # To support BWC, we check if DLQ exists in core (< 5.4). If it doesn't, we use nil to resort to previous behavior.
    @dlq_writer = dlq_enabled? ? execution_context.dlq_writer : nil

    if data_stream_config?
      @event_mapper = -> (e) { data_stream_event_action_tuple(e) }
      @event_target = -> (e) { data_stream_name(e) }
      @index = "#{data_stream_type}-#{data_stream_dataset}-#{data_stream_namespace}".freeze # default name
    else
      @event_mapper = -> (e) { event_action_tuple(e) }
      @event_target = -> (e) { e.sprintf(@index) }
    end

    @bulk_request_metrics = metric.namespace(:bulk_requests)
    @document_level_metrics = metric.namespace(:documents)

    if ecs_compatibility == :v8
      @logger.warn("Elasticsearch Output configured with `ecs_compatibility => v8`, which resolved to an UNRELEASED preview of version 8.0.0 of the Elastic Common Schema. " +
                   "Once ECS v8 and an updated release of this plugin are publicly available, you will need to update this plugin to resolve this warning.")
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
    retrying_submit map_events(events)
  end

  def map_events(events)
    events.map(&@event_mapper)
  end

  def wait_for_successful_connection
    after_successful_connection_done = @after_successful_connection_done
    return unless after_successful_connection_done
    stoppable_sleep 1 until after_successful_connection_done.true?

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
    @after_successful_connection_thread.join unless @after_successful_connection_thread.nil?
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

    if action == 'update'
      params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @upsert != ""
      params[:_script] = event.sprintf(@script) if @script != ""
      params[retry_on_conflict_action_name] = @retry_on_conflict
    end

    params[:version] = event.sprintf(@version) if @version
    params[:version_type] = event.sprintf(@version_type) if @version_type

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

  # @return Hash (initial) parameters for given event
  # @private shared event params factory between index and data_stream mode
  def common_event_params(event)
    params = {
        :_id => @document_id ? event.sprintf(@document_id) : nil,
        :_index => @event_target.call(event),
        routing_field_name => @routing ? event.sprintf(@routing) : nil
    }

    if @pipeline
      value = event.sprintf(@pipeline)
      # convention: empty string equates to not using a pipeline
      # this is useful when using a field reference in the pipeline setting, e.g.
      #      elasticsearch {
      #        pipeline => "%{[@metadata][pipeline]}"
      #      }
      params[:pipeline] = value unless value.empty?
    end

    params
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
    @logger.error("Failed to install template", message: e.message, exception: e.class, backtrace: e.backtrace)
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
end
