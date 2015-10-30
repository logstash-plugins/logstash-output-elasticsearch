# encoding: utf-8
require "logstash/namespace"
require "logstash/environment"
require "logstash/outputs/base"
require "logstash/json"
require "concurrent"
require "stud/buffer"
require "socket" # for Socket.gethostname
require "thread" # for safe queueing
require "uri" # for escaping user input
require "logstash/outputs/elasticsearch/http_client"

# This plugin is the recommended method of storing logs in Elasticsearch.
# If you plan on using the Kibana web interface, you'll want to use this output.
#
# This output only speaks the HTTP protocol. HTTP is the preferred protocol for interacting with Elasticsearch as of Logstash 2.0.
# We strongly encourage the use of HTTP over the node protocol for a number of reasons. HTTP is only marginally slower,
# yet far easier to administer and work with. When using the HTTP protocol one may upgrade Elasticsearch versions without having
# to upgrade Logstash in lock-step. For those still wishing to use the node or transport protocols please see
# the https://www.elastic.co/guide/en/logstash/2.0/plugins-outputs-elasticsearch_java.html[logstash-output-elasticsearch_java] plugin.
#
# You can learn more about Elasticsearch at <https://www.elastic.co/products/elasticsearch>
#
# ==== Retry Policy
#
# This plugin uses the Elasticsearch bulk API to optimize its imports into Elasticsearch. These requests may experience
# either partial or total failures. Events are retried if they fail due to either a network error or the status codes
# 429 (the server is busy), 409 (Version Conflict), or 503 (temporary overloading/maintenance).
#
# The retry policy's logic can be described as follows:
#
# - Block and retry all events in the bulk response that experience transient network exceptions until
#   a successful submission is received by Elasticsearch.
# - Retry the subset of sent events which resulted in ES errors of a retryable nature.
# - Events which returned retryable error codes will be pushed onto a separate queue for
#   retrying events. Events in this queue will be retried a maximum of 5 times by default (configurable through :max_retries).
#   The size of this queue is capped by the value set in :retry_max_items.
# - Events from the retry queue are submitted again when the queue reaches its max size or when
#   the max interval time is reached. The max interval time is configurable via :retry_max_interval.
# - Events which are not retryable or have reached their max retry count are logged to stderr.
#
# ==== DNS Caching
#
# This plugin uses the JVM to lookup DNS entries and is subject to the value of https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html[networkaddress.cache.ttl],
# a global setting for the JVM.
#
# As an example, to set your DNS TTL to 1 second you would set
# the `LS_JAVA_OPTS` environment variable to `-Dnetwordaddress.cache.ttl=1`.
#
# Keep in mind that a connection with keepalive enabled will
# not reevaluate its DNS value while the keepalive is in effect.
class LogStash::Outputs::ElasticSearch < LogStash::Outputs::Base
  attr_reader :client

  include Stud::Buffer
  RETRYABLE_CODES = [409, 429, 503]
  SUCCESS_CODES = [200, 201]

  config_name "elasticsearch"

  # The index to write events to. This can be dynamic using the `%{foo}` syntax.
  # The default value will partition your indices by day so you can more easily
  # delete old data or only search specific date ranges.
  # Indexes may not contain uppercase characters.
  # For weekly indexes ISO 8601 format is recommended, eg. logstash-%{+xxxx.ww}
  config :index, :validate => :string, :default => "logstash-%{+YYYY.MM.dd}"

  # The index type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion `%{foo}` works here.
  #
  # Deprecated in favor of `document_type` field.
  config :index_type, :validate => :string, :obsolete => "Please use the 'document_type' setting instead. It has the same effect, but is more appropriately named."

  # The document type to write events to. Generally you should try to write only
  # similar events to the same 'type'. String expansion `%{foo}` works here.
  # Unless you set 'document_type', the event 'type' will be used if it exists
  # otherwise the document type will be assigned the value of 'logs'
  config :document_type, :validate => :string

  # Starting in Logstash 1.3 (unless you set option `manage_template` to false)
  # a default mapping template for Elasticsearch will be applied, if you do not
  # already have one set to match the index pattern defined (default of
  # `logstash-%{+YYYY.MM.dd}`), minus any variables.  For example, in this case
  # the template will be applied to all indices starting with `logstash-*`
  #
  # If you have dynamic templating (e.g. creating indices based on field names)
  # then you should set `manage_template` to false and use the REST API to upload
  # your templates manually.
  config :manage_template, :validate => :boolean, :default => true

  # This configuration option defines how the template is named inside Elasticsearch.
  # Note that if you have used the template management features and subsequently
  # change this, you will need to prune the old template manually, e.g.
  #
  # `curl -XDELETE <http://localhost:9200/_template/OldTemplateName?pretty>`
  #
  # where `OldTemplateName` is whatever the former setting was.
  config :template_name, :validate => :string, :default => "logstash"

  # You can set the path to your own template here, if you so desire.
  # If not set, the included template will be used.
  config :template, :validate => :path

  # Overwrite the current template with whatever is configured
  # in the `template` and `template_name` directives.
  config :template_overwrite, :validate => :boolean, :default => false

  # The document ID for the index. Useful for overwriting existing entries in
  # Elasticsearch with the same ID.
  config :document_id, :validate => :string

  # A routing override to be applied to all processed events.
  # This can be dynamic using the `%{foo}` syntax.
  config :routing, :validate => :string

  # Sets the host(s) of the remote instance. If given an array it will load balance requests across the hosts specified in the `hosts` parameter.
  # Remember the `http` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http[http] address (eg. 9200, not 9300).
  #     `"127.0.0.1"`
  #     `["127.0.0.1:9200","127.0.0.2:9200"]`
  # It is important to exclude http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[dedicated master nodes] from the `hosts` list
  # to prevent LS from sending bulk requests to the master nodes.  So this parameter should only reference either data or client nodes in Elasticsearch.

  config :hosts, :validate => :array

  config :host, :obsolete => "Please use the 'hosts' setting instead. You can specify multiple entries separated by comma in 'host:port' format."

  # The port setting is obsolete.  Please use the 'hosts' setting instead.
  # Hosts entries can be in "host:port" format.
  config :port, :obsolete => "Please use the 'hosts' setting instead. Hosts entries can be in 'host:port' format."

  # This plugin uses the bulk index API for improved indexing performance.
  # To make efficient bulk API calls, we will buffer a certain number of
  # events before flushing that out to Elasticsearch. This setting
  # controls how many events will be buffered before sending a batch
  # of events. Increasing the `flush_size` has an effect on Logstash's heap size.
  # Remember to also increase the heap size using `LS_HEAP_SIZE` if you are sending big documents
  # or have increased the `flush_size` to a higher value.
  config :flush_size, :validate => :number, :default => 500

  # The amount of time since last flush before a flush is forced.
  #
  # This setting helps ensure slow event rates don't get stuck in Logstash.
  # For example, if your `flush_size` is 100, and you have received 10 events,
  # and it has been more than `idle_flush_time` seconds since the last flush,
  # Logstash will flush those 10 events automatically.
  #
  # This helps keep both fast and slow log streams moving along in
  # near-real-time.
  config :idle_flush_time, :validate => :number, :default => 1

  # The Elasticsearch action to perform. Valid actions are:
  #
  # - index: indexes a document (an event from Logstash).
  # - delete: deletes a document by id (An id is required for this action)
  # - create: indexes a document, fails if a document by that id already exists in the index.
  # - update: updates a document by id. Update has a special case where you can upsert -- update a
  #   document if not already present. See the `upsert` option
  #
  # For more details on actions, check out the http://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html[Elasticsearch bulk API documentation]
  config :action, :validate => %w(index delete create update), :default => "index"

  # Username to authenticate to a secure Elasticsearch cluster
  config :user, :validate => :string
  # Password to authenticate to a secure Elasticsearch cluster
  config :password, :validate => :password

  # HTTP Path at which the Elasticsearch server lives. Use this if you must run Elasticsearch behind a proxy that remaps
  # the root path for the Elasticsearch HTTP API lives.
  config :path, :validate => :string, :default => "/"

  # Enable SSL/TLS secured communication to Elasticsearch cluster
  config :ssl, :validate => :boolean, :default => false

  # Option to validate the server's certificate. Disabling this severely compromises security.
  # For more information on disabling certificate verification please read
  # https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf
  config :ssl_certificate_verification, :validate => :boolean, :default => true

  # The .cer or .pem file to validate the server's certificate
  config :cacert, :validate => :path

  # The JKS truststore to validate the server's certificate.
  # Use either `:truststore` or `:cacert`
  config :truststore, :validate => :path

  # Set the truststore password
  config :truststore_password, :validate => :password

  # The keystore used to present a certificate to the server.
  # It can be either .jks or .p12
  config :keystore, :validate => :path

  # Set the truststore password
  config :keystore_password, :validate => :password

  # This setting asks Elasticsearch for the list of all cluster nodes and adds them to the hosts list.
  # Note: This will return ALL nodes with HTTP enabled (including master nodes!). If you use
  # this with master nodes, you probably want to disable HTTP on them by setting
  # `http.enabled` to false in their elasticsearch.yml. You can either use the `sniffing` option or
  # manually enter multiple Elasticsearch hosts using the `hosts` paramater.
  config :sniffing, :validate => :boolean, :default => false

  # How long to wait, in seconds, between sniffing attempts
  config :sniffing_delay, :validate => :number, :default => 5

  # Set max retry for each event
  config :max_retries, :validate => :number, :default => 3

  # Set retry policy for events that failed to send
  config :retry_max_items, :validate => :number, :default => 5000

  # Set max interval between bulk retries
  config :retry_max_interval, :validate => :number, :default => 5

  # Set the address of a forward HTTP proxy.
  # Can be either a string, such as `http://localhost:123` or a hash in the form
  # of `{host: 'proxy.org' port: 80 scheme: 'http'}`.
  # Note, this is NOT a SOCKS proxy, but a plain HTTP proxy
  config :proxy

  # Enable `doc_as_upsert` for update mode.
  # Create a new document with source if `document_id` doesn't exist in Elasticsearch
  config :doc_as_upsert, :validate => :boolean, :default => false

  # Set upsert content for update mode.
  # Create a new document with this parameter as json string if `document_id` doesn't exists
  config :upsert, :validate => :string, :default => ""

  # Set the timeout for network operations and requests sent Elasticsearch. If
  # a timeout occurs, the request will be retried.
  config :timeout, :validate => :number

  public
  def register
    require "logstash/outputs/elasticsearch/template_manager"

    @hosts = Array(@hosts)
    # retry-specific variables
    @retry_flush_mutex = Mutex.new
    @retry_close_requested = Concurrent::AtomicBoolean.new(false)
    # needs flushing when interval
    @retry_queue_needs_flushing = ConditionVariable.new
    @retry_queue_not_full = ConditionVariable.new
    @retry_queue = Queue.new
    @submit_mutex = Mutex.new

    client_settings = {}
    common_options = {
      :client_settings => client_settings,
      :sniffing => @sniffing,
      :sniffing_delay => @sniffing_delay
    }

    common_options[:timeout] = @timeout if @timeout
    client_settings[:path] = "/#{@path}/".gsub(/\/+/, "/") # Normalize slashes
    @logger.debug? && @logger.debug("Normalizing http path", :path => @path, :normalized => client_settings[:path])

    if @hosts.nil? || @hosts.empty?
      @logger.info("No 'host' set in elasticsearch output. Defaulting to localhost")
      @hosts = ["localhost"]
    end

    client_settings.merge! setup_ssl()
    client_settings.merge! setup_proxy()
    common_options.merge! setup_basic_auth()

    # Update API setup
    update_options = {
      :upsert => @upsert,
      :doc_as_upsert => @doc_as_upsert
    }
    common_options.merge! update_options if @action == 'update'

    @client = LogStash::Outputs::Elasticsearch::HttpClient.new(
      common_options.merge(:hosts => @hosts, :logger => @logger)
    )

    TemplateManager.install_template(self)

    @logger.info("New Elasticsearch output", :hosts => @hosts)

    @client_idx = 0

    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )

    @retry_timer_thread = Thread.new do
      loop do
        sleep(@retry_max_interval)
        @retry_flush_mutex.synchronize { @retry_queue_needs_flushing.signal }
      end
    end

    @retry_thread = Thread.new do
      while @retry_close_requested.false?
        @retry_flush_mutex.synchronize { @retry_queue_needs_flushing.wait(@retry_flush_mutex) }
        retry_flush
      end
    end
  end # def register

  def receive(event)
    event['@metadata']['retry_count'] = 0

    wait_for_retry_queue_room # Apply back pressure if needed

    params = event_action_params(event)
    action = event.sprintf(@action)
    buffer_receive([action, params, event])
  end # def receive

  # block until we have not maxed out our
  # retry queue. This is applying back-pressure
  # to slow down the receive-rate
  def wait_for_retry_queue_room
    @retry_flush_mutex.synchronize {
      @retry_queue_not_full.wait(@retry_flush_mutex) while @retry_queue.size > @retry_max_items
    }
  end

  # get the action parameters for the given event
  def event_action_params(event)
    type = get_event_type(event)

    params = {
      :_id => @document_id ? event.sprintf(@document_id) : nil,
      :_index => event.sprintf(@index),
      :_type => type,
      :_routing => @routing ? event.sprintf(@routing) : nil
    }

    params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @action == 'update' && @upsert != ""
    params
  end

  # Determine the correct value for the 'type' field for the given event
  def get_event_type(event)
    # Set the 'type' value for the index.
    type = if @document_type
             event.sprintf(@document_type)
           else
             event["type"] || "logs"
           end

    if !(type.is_a?(String) || type.is_a?(Numeric))
      @logger.warn("Bad event type! Non-string/integer type value set!", :type_class => type.class, :type_value => type.to_s, :event => event)
    end

    type.to_s
  end

  public
  # The submit method can be called from both the
  # Stud::Buffer flush thread and from our own retry thread.
  def submit(actions)
    @submit_mutex.synchronize do
      es_actions = actions.map { |a, doc, event| [a, doc, event.to_hash] }

      bulk_response = @client.bulk(es_actions)

      next unless bulk_response["errors"]

      actions_to_retry = []

      bulk_response["items"].each_with_index do |resp,idx|
        action_type, action_props = resp.first

        status = action_props["status"]
        action = actions[idx]

        if RETRYABLE_CODES.include?(status)
          @logger.warn "retrying failed action with response code: #{status}"
          actions_to_retry << action
        elsif not SUCCESS_CODES.include?(status)
          @logger.warn "Failed action. ", status: status, action: action, response: resp
        end
      end

      retry_push(actions_to_retry) unless actions_to_retry.empty?
    end
  end

  # When there are exceptions raised upon submission, we raise an exception so that
  # Stud::Buffer will retry to flush
  public
  def flush(actions, close = false)
    begin
      submit(actions)
    rescue Manticore::SocketException => e
      # If we can't even connect to the server let's just print out the URL (:hosts is actually a URL)
      # and let the user sort it out from there
      @logger.error(
        "Attempted to send a bulk request to Elasticsearch configured at '#{@client.client_options[:hosts]}',"+
          " but Elasticsearch appears to be unreachable or down!",
        :client_config => @client.client_options,
        :error_message => e.message
      )
      @logger.debug("Failed actions for last bad bulk request!", :actions => actions)
    rescue => e
      # For all other errors print out full connection issues
      @logger.error(
        "Attempted to send a bulk request to Elasticsearch configured at '#{@client.client_options[:hosts]}'," +
            " but an error occurred and it failed! Are you sure you can reach elasticsearch from this machine using " +
          "the configuration provided?",
        :client_config => @client.client_options,
        :error_message => e.message,
        :error_class => e.class.name,
        :backtrace => e.backtrace
      )

      @logger.debug("Failed actions for last bad bulk request!", :actions => actions)

      raise e
    end
  end # def flush

  public
  def close
    @client.stop_sniffing!

    @retry_close_requested.make_true
    # First, make sure retry_timer_thread is stopped
    # to ensure we do not signal a retry based on
    # the retry interval.
    Thread.kill(@retry_timer_thread)
    @retry_timer_thread.join
    # Signal flushing in the case that #retry_flush is in
    # the process of waiting for a signal.
    @retry_flush_mutex.synchronize { @retry_queue_needs_flushing.signal }
    # Now, #retry_flush is ensured to not be in a state of
    # waiting and can be safely joined into the main thread
    # for further final execution of an in-process remaining call.
    @retry_thread.join

    # execute any final actions along with a proceeding retry for any
    # final actions that did not succeed.
    buffer_flush(:final => true)
    retry_flush
  end

  private
  def setup_proxy
    return {} unless @proxy

    # Symbolize keys
    proxy = if @proxy.is_a?(Hash)
              Hash[@proxy.map {|k,v| [k.to_sym, v]}]
            elsif @proxy.is_a?(String)
              @proxy
            else
              raise LogStash::ConfigurationError, "Expected 'proxy' to be a string or hash, not '#{@proxy}''!"
            end

    return {:proxy => proxy}
  end

  private
  def setup_ssl
    return {} unless @ssl

    if @cacert && @truststore
      raise(LogStash::ConfigurationError, "Use either \"cacert\" or \"truststore\" when configuring the CA certificate") if @truststore
    end

    ssl_options = {}

    if @cacert
      ssl_options[:ca_file] = @cacert
    elsif @truststore
      ssl_options[:truststore_password] = @truststore_password.value if @truststore_password
    end

    ssl_options[:truststore] = @truststore if @truststore
    if @keystore
      ssl_options[:keystore] = @keystore
      ssl_options[:keystore_password] = @keystore_password.value if @keystore_password
    end
    if @ssl_certificate_verification == false
      @logger.warn [
        "** WARNING ** Detected UNSAFE options in elasticsearch output configuration!",
        "** WARNING ** You have enabled encryption but DISABLED certificate verification.",
        "** WARNING ** To make sure your data is secure change :ssl_certificate_verification to true"
      ].join("\n")
      ssl_options[:verify] = false
    end
    { ssl: ssl_options }
  end

  private
  def setup_basic_auth
    return {} unless @user && @password

    {
      :user => @user,
      :password => @password.value
    }
  end

  private
  # in charge of submitting any actions in @retry_queue that need to be
  # retried
  #
  # This method is not called concurrently. It is only called by @retry_thread
  # and once that thread is ended during the close process, a final call
  # to this method is done upon close in the main thread.
  def retry_flush()
    unless @retry_queue.empty?
      buffer = @retry_queue.size.times.map do
        next_action, next_doc, next_event = @retry_queue.pop
        next_event['@metadata']['retry_count'] += 1

        if next_event['@metadata']['retry_count'] > @max_retries
          @logger.error "too many attempts at sending event. dropping: #{next_event}"
          nil
        else
          [next_action, next_doc, next_event]
        end
      end.compact

      submit(buffer) unless buffer.empty?
    end

    @retry_flush_mutex.synchronize {
      @retry_queue_not_full.signal if @retry_queue.size < @retry_max_items
    }
  end

  private
  def retry_push(actions)
    Array(actions).each{|action| @retry_queue << action}
    @retry_flush_mutex.synchronize {
      @retry_queue_needs_flushing.signal if @retry_queue.size >= @retry_max_items
    }
  end

  @@plugins = Gem::Specification.find_all{|spec| spec.name =~ /logstash-output-elasticsearch-/ }

  @@plugins.each do |plugin|
    name = plugin.name.split('-')[-1]
    require "logstash/outputs/elasticsearch/#{name}"
  end

end # class LogStash::Outputs::Elasticsearch
