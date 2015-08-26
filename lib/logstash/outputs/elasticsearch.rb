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
require 'logstash-output-elasticsearch_jars.rb'

# This output lets you store logs in Elasticsearch and is the most recommended
# output for Logstash. If you plan on using the Kibana web interface, you'll
# need to use this output.
#
# *VERSION NOTE*: Your Elasticsearch cluster must be running Elasticsearch 1.0.0 or later.
#
# If you want to set other Elasticsearch options that are not exposed directly
# as configuration options, there are two methods:
#
# * Create an `elasticsearch.yml` file in the $PWD of the Logstash process
# * Pass in es.* java properties (`java -Des.node.foo=` or `ruby -J-Des.node.foo=`)
#
# With the default `protocol` setting ("node"), this plugin will join your
# Elasticsearch cluster as a client node, so it will show up in Elasticsearch's
# cluster status.
#
# You can learn more about Elasticsearch at <https://www.elastic.co/products/elasticsearch>
#
# ==== Operational Notes
#
# If using the default `protocol` setting ("node"), your firewalls might need
# to permit port 9300 in *both* directions (from Logstash to Elasticsearch, and
# Elasticsearch to Logstash)
#
# ==== Retry Policy
#
# By default all bulk requests to ES are synchronous. Not all events in the bulk requests
# always make it successfully. For example, there could be events which are not formatted
# correctly for the index they are targeting (type mismatch in mapping). So that we minimize loss of 
# events, we have a specific retry policy in place. We retry all events which fail to be reached by 
# Elasticsearch for network related issues. We retry specific events which exhibit errors under a separate 
# policy described below. Events of this nature are ones which experience ES error codes described as 
# retryable errors.
#
# *Retryable Errors:*
#
# - 429, Too Many Requests (RFC6585)
# - 503, The server is currently unable to handle the request due to a temporary overloading or maintenance of the server.
# 
# Here are the rules of what is retried when:
#
# - Block and retry all events in bulk response that experiences transient network exceptions until
#   a successful submission is received by Elasticsearch.
# - Retry subset of sent events which resulted in ES errors of a retryable nature which can be found 
#   in RETRYABLE_CODES
# - For events which returned retryable error codes, they will be pushed onto a separate queue for 
#   retrying events. events in this queue will be retried a maximum of 5 times by default (configurable through :max_retries). The size of 
#   this queue is capped by the value set in :retry_max_items.
# - Events from the retry queue are submitted again either when the queue reaches its max size or when
#   the max interval time is reached, which is set in :retry_max_interval.
# - Events which are not retryable or have reached their max retry count are logged to stderr.
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
  config :index_type, :validate => :string, :deprecated => "Please use the 'document_type' setting instead. It has the same effect, but is more appropriately named."

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

  # The name of your cluster if you set it on the Elasticsearch side. Useful
  # for discovery when using `node` or `transport` protocols.
  # By default, it looks for a cluster named 'elasticsearch'.
  config :cluster, :validate => :string

  # For the `node` protocol, if you do not specify `host`, it will attempt to use
  # multicast discovery to connect to Elasticsearch.  If http://www.elastic.co/guide/en/elasticsearch/guide/current/_important_configuration_changes.html#_prefer_unicast_over_multicast[multicast is disabled] in Elasticsearch, 
  # you must include the hostname or IP address of the host(s) to use for Elasticsearch unicast discovery.
  # Remember the `node` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-transport.html#modules-transport[transport] address (eg. 9300, not 9200).
  #     `"127.0.0.1"`
  #     `["127.0.0.1:9300","127.0.0.2:9300"]`
  # When setting hosts for `node` protocol, it is important to confirm that at least one non-client
  # node is listed in the `host` list.  Also keep in mind that the `host` parameter when used with 
  # the `node` protocol is for *discovery purposes only* (not for load balancing).  When multiple hosts 
  # are specified, it will contact the first host to see if it can use it to discover the cluster.  If not, 
  # then it will contact the second host in the list and so forth. With the `node` protocol, 
  # Logstash will join the Elasticsearch cluster as a node client (which has a copy of the cluster
  # state) and this node client is the one that will automatically handle the load balancing of requests 
  # across data nodes in the cluster.  
  # If you are looking for a high availability setup, our recommendation is to use the `transport` protocol (below), 
  # set up multiple http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[client nodes] and list the client nodes in the `host` parameter.
  # 
  # For the `transport` protocol, it will load balance requests across the hosts specified in the `host` parameter.
  # Remember the `transport` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-transport.html#modules-transport[transport] address (eg. 9300, not 9200).
  #     `"127.0.0.1"`
  #     `["127.0.0.1:9300","127.0.0.2:9300"]`
  # There is also a `sniffing` option (see below) that can be used with the transport protocol to instruct it to use the host to sniff for
  # "alive" nodes in the cluster and automatically use it as the hosts list (but will skip the dedicated master nodes).  
  # If you do not use the sniffing option, it is important to exclude http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[dedicated master nodes] from the `host` list
  # to prevent Logstash from sending bulk requests to the master nodes. So this parameter should only reference either data or client nodes.
  #
  # For the `http` protocol, it will load balance requests across the hosts specified in the `host` parameter.
  # Remember the `http` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http[http] address (eg. 9200, not 9300).
  #     `"127.0.0.1"`
  #     `["127.0.0.1:9200","127.0.0.2:9200"]`
  # It is important to exclude http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[dedicated master nodes] from the `host` list
  # to prevent LS from sending bulk requests to the master nodes.  So this parameter should only reference either data or client nodes.

  config :host, :validate => :array

  # The port for Elasticsearch transport to use.
  #
  # If you do not set this, the following defaults are used:
  # * `protocol => http` - port 9200
  # * `protocol => transport` - port 9300-9305
  # * `protocol => node` - port 9300-9305
  config :port, :validate => :string

  # The name/address of the host to bind to for Elasticsearch clustering
  config :bind_host, :validate => :string

  # This is only valid for the 'node' protocol.
  #
  # The port for the node to listen on.
  config :bind_port, :validate => :number

  # Run the Elasticsearch server embedded in this process.
  # This option is useful if you want to run a single Logstash process that
  # handles log processing and indexing; it saves you from needing to run
  # a separate Elasticsearch process. An example use case is 
  # proof-of-concept testing.
  # WARNING: This is not recommended for production use!
  config :embedded, :validate => :boolean, :default => false

  # If you are running the embedded Elasticsearch server, you can set the http
  # port it listens on here; it is not common to need this setting changed from
  # default.
  config :embedded_http_port, :validate => :string, :default => "9200-9300"

  # This setting no longer does anything. It exists to keep config validation
  # from failing. It will be removed in future versions.
  config :max_inflight_requests, :validate => :number, :default => 50, :deprecated => true

  # The node name Elasticsearch will use when joining a cluster.
  #
  # By default, this is generated internally by the ES client.
  config :node_name, :validate => :string

  # This plugin uses the bulk index api for improved indexing performance.
  # To make efficient bulk api calls, we will buffer a certain number of
  # events before flushing that out to Elasticsearch. This setting
  # controls how many events will be buffered before sending a batch
  # of events.
  config :flush_size, :validate => :number, :default => 5000

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

  # Choose the protocol used to talk to Elasticsearch.
  #
  # The 'node' protocol (default) will connect to the cluster as a normal Elasticsearch
  # node (but will not store data). If you use the `node` protocol, you must permit
  # bidirectional communication on the port 9300 (or whichever port you have
  # configured).
  #
  # If you do not specify the `host` parameter, it will use  multicast for http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery-zen.html[Elasticsearch discovery].  While this may work in a test/dev environment where multicast is enabled in 
  # Elasticsearch, we strongly recommend http://www.elastic.co/guide/en/elasticsearch/guide/current/_important_configuration_changes.html#_prefer_unicast_over_multicast[disabling multicast]
  # in Elasticsearch.  To connect to an Elasticsearch cluster with multicast disabled,
  # you must include the `host` parameter (see relevant section above).  
  #
  # The 'transport' protocol will connect to the host you specify and will
  # not show up as a 'node' in the Elasticsearch cluster. This is useful
  # in situations where you cannot permit connections outbound from the
  # Elasticsearch cluster to this Logstash server.
  #
  # The 'http' protocol will use the Elasticsearch REST/HTTP interface to talk
  # to elasticsearch.
  #
  # All protocols will use bulk requests when talking to Elasticsearch.
  #
  # The default `protocol` setting under java/jruby is "node". The default
  # `protocol` on non-java rubies is "http"
  config :protocol, :validate => [ "node", "transport", "http" ]

  # The Elasticsearch action to perform. Valid actions are: `index`, `delete`, `create`, `update` and `create_unless_exists`.
  #
  # Use of this setting *REQUIRES* you also configure the `document_id` setting
  # because `delete` actions all require a document id.
  #
  # What does each action do?
  #
  # - index: indexes a document (an event from Logstash).
  # - delete: deletes a document by id
  # - create: indexes a document, fails if a document by that id already exists in the index.
  # - update: updates a document by id
  # following action is not supported by HTTP protocol
  # - create_unless_exists: creates a document, fails if no id is provided
  #
  # For more details on actions, check out the http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/docs-bulk.html[Elasticsearch bulk API documentation]
  config :action, :validate => :string, :default => "index"

  # Username and password (only valid when protocol is HTTP; this setting works with HTTP or HTTPS auth)
  config :user, :validate => :string
  config :password, :validate => :password

  # HTTP Path at which the Elasticsearch server lives. Use this if you must run ES behind a proxy that remaps
  # the root path for the Elasticsearch HTTP API lives. This option is ignored for non-HTTP transports.
  config :path, :validate => :string, :default => "/"

  # SSL Configurations (only valid when protocol is HTTP)
  #
  # Enable SSL
  config :ssl, :validate => :boolean, :default => false

  # Validate the server's certificate
  # Disabling this severely compromises security
  # For more information read https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf
  config :ssl_certificate_verification, :validate => :boolean, :default => true

  # The .cer or .pem file to validate the server's certificate
  config :cacert, :validate => :path

  # The JKS truststore to validate the server's certificate
  # Use either `:truststore` or `:cacert`
  config :truststore, :validate => :path

  # Set the truststore password
  config :truststore_password, :validate => :password

  # The keystore used to present a certificate to the server
  # It can be either .jks or .p12
  config :keystore, :validate => :path

  # Set the truststore password
  config :keystore_password, :validate => :password

  # Enable cluster sniffing (transport only)
  # Asks host for the list of all cluster nodes and adds them to the hosts list
  config :sniffing, :validate => :boolean, :default => false

  # Set max retry for each event
  config :max_retries, :validate => :number, :default => 3

  # Set retry policy for events that failed to send
  config :retry_max_items, :validate => :number, :default => 5000

  # Set max interval between bulk retries
  config :retry_max_interval, :validate => :number, :default => 5

  # Set the address of a forward HTTP proxy. Must be used with the 'http' protocol
  # Can be either a string, such as 'http://localhost:123' or a hash in the form
  # {host: 'proxy.org' port: 80 scheme: 'http'}
  # Note, this is NOT a SOCKS proxy, but a plain HTTP proxy
  config :proxy

  # Enable doc_as_upsert for update mode
  # create a new document with source if document_id doesn't exists
  config :doc_as_upsert, :validate => :boolean, :default => false

  # Set upsert content for update mode
  # create a new document with this parameter as json string if document_id doesn't exists
  config :upsert, :validate => :string, :default => ""

  public
  def register
    @submit_mutex = Mutex.new
    # retry-specific variables
    @retry_flush_mutex = Mutex.new
    @retry_teardown_requested = Concurrent::AtomicBoolean.new(false)
    # needs flushing when interval
    @retry_queue_needs_flushing = ConditionVariable.new
    @retry_queue_not_full = ConditionVariable.new
    @retry_queue = Queue.new

    client_settings = {}


    if @protocol.nil?
      @protocol = LogStash::Environment.jruby? ? "node" : "http"
    end

    if @protocol == "http"
      if @action == "create_unless_exists"
        raise(LogStash::ConfigurationError, "action => 'create_unless_exists' is not supported under the HTTP protocol");
      end

      client_settings[:path] = "/#{@path}/".gsub(/\/+/, "/") # Normalize slashes
      @logger.debug? && @logger.debug("Normalizing http path", :path => @path, :normalized => client_settings[:path])
    end

    if ["node", "transport"].include?(@protocol)
      # Node or TransportClient; requires JRuby
      raise(LogStash::PluginLoadingError, "This configuration requires JRuby. If you are not using JRuby, you must set 'protocol' to 'http'. For example: output { elasticsearch { protocol => \"http\" } }") unless LogStash::Environment.jruby?

      client_settings["cluster.name"] = @cluster if @cluster
      client_settings["network.host"] = @bind_host if @bind_host
      client_settings["transport.tcp.port"] = @bind_port if @bind_port
      client_settings["client.transport.sniff"] = @sniffing
 
      if @node_name
        client_settings["node.name"] = @node_name
      else
        client_settings["node.name"] = "logstash-#{Socket.gethostname}-#{$$}-#{object_id}"
      end

      @@plugins.each do |plugin|
        name = plugin.name.split('-')[-1]
        client_settings.merge!(LogStash::Outputs::ElasticSearch.const_get(name.capitalize).create_client_config(self))
      end
    end

    require "logstash/outputs/elasticsearch/protocol"

    if @port.nil?
      @port = case @protocol
        when "http"; "9200"
        when "transport", "node"; "9300-9305"
      end
    end

    if @host.nil? && @protocol != "node" # node can use zen discovery
      @logger.info("No 'host' set in elasticsearch output. Defaulting to localhost")
      @host = ["localhost"]
    end

    client_settings.merge! setup_ssl()
    client_settings.merge! setup_proxy()

    common_options = {
      :protocol => @protocol,
      :client_settings => client_settings
    }

    common_options.merge! setup_basic_auth()

    # Update API setup
    update_options = {
      :upsert => @upsert,
      :doc_as_upsert => @doc_as_upsert
    }
    common_options.merge! update_options if @action == 'update'

    client_class = case @protocol
      when "transport"
        LogStash::Outputs::Elasticsearch::Protocols::TransportClient
      when "node"
        LogStash::Outputs::Elasticsearch::Protocols::NodeClient
      when /http/
        LogStash::Outputs::Elasticsearch::Protocols::HTTPClient
    end

    if @embedded
      raise(LogStash::ConfigurationError, "The 'embedded => true' setting is only valid for the elasticsearch output under JRuby. You are running #{RUBY_DESCRIPTION}") unless LogStash::Environment.jruby?
      @logger.warn("The 'embedded => true' setting is enabled. This is not recommended for production use!!!")
#      LogStash::Environment.load_elasticsearch_jars!

      # Default @host with embedded to localhost. This should help avoid
      # newbies tripping on ubuntu and other distros that have a default
      # firewall that blocks multicast.
      @host ||= ["localhost"]

      # Start Elasticsearch local.
      start_local_elasticsearch
    end

    @client = Array.new

    if protocol == "node" || @host.nil? # if @protocol is "node" or @host is not set
      options = { :host => @host, :port => @port }.merge(common_options)
      @client = [client_class.new(options)]
    else # if @protocol in ["transport","http"]
      @client = @host.map do |host|
        (_host,_port) = host.split ":"
        options = { :host => _host, :port => _port || @port }.merge(common_options)
        @logger.info "Create client to elasticsearch server on #{_host}:#{_port}"
        client_class.new(options)
      end # @host.map
    end

    if @manage_template
      for client in @client
        begin
          @logger.info("Automatic template management enabled", :manage_template => @manage_template.to_s)
          client.template_install(@template_name, get_template, @template_overwrite)
          break
        rescue => e
          @logger.error("Failed to install template: #{e.message}")
        end
      end # for @client loop
    end # if @manage_templates

    @logger.info("New Elasticsearch output", :cluster => @cluster,
                 :host => @host, :port => @port, :embedded => @embedded,
                 :protocol => @protocol)

    @client_idx = 0
    @current_client = @client[@client_idx]

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
      while @retry_teardown_requested.false?
        @retry_flush_mutex.synchronize { @retry_queue_needs_flushing.wait(@retry_flush_mutex) }
        retry_flush
      end
    end
  end # def register


  public
  def get_template
    if @template.nil?
      @template = ::File.expand_path('elasticsearch/elasticsearch-template.json', ::File.dirname(__FILE__))
      if !File.exists?(@template)
        raise "You must specify 'template => ...' in your elasticsearch output (I looked for '#{@template}')"
      end
    end
    template_json = IO.read(@template).gsub(/\n/,'')
    template = LogStash::Json.load(template_json)
    @logger.info("Using mapping template", :template => template)
    return template
  end # def get_template

  public
  def receive(event)
    return unless output?(event)

    # block until we have not maxed out our 
    # retry queue. This is applying back-pressure
    # to slow down the receive-rate
    @retry_flush_mutex.synchronize {
      @retry_queue_not_full.wait(@retry_flush_mutex) while @retry_queue.size > @retry_max_items
    }

    event['@metadata']['retry_count'] = 0

    # Set the 'type' value for the index.
    type = if @document_type
             event.sprintf(@document_type)
           elsif @index_type # deprecated
             event.sprintf(@index_type)
           else
             event["type"] || "logs"
           end

    params = {
      :_id => @document_id ? event.sprintf(@document_id) : nil,
      :_index => event.sprintf(@index),
      :_type => type,
      :_routing => @routing ? event.sprintf(@routing) : nil
    }
    
    params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @action == 'update' && @upsert != ""

    buffer_receive([event.sprintf(@action), params, event])
  end # def receive

  public
  # synchronize the @current_client.bulk call to avoid concurrency/thread safety issues with the
  # # client libraries which might not be thread safe. the submit method can be called from both the
  # # Stud::Buffer flush thread and from our own retry thread.
  def submit(actions)
    es_actions = actions.map { |a, doc, event| [a, doc, event.to_hash] }
    @submit_mutex.lock
    begin
      bulk_response = @current_client.bulk(es_actions)
    ensure
      @submit_mutex.unlock
    end
    if bulk_response["errors"]
      actions_with_responses = actions.zip(bulk_response['statuses'])
      actions_to_retry = []
      actions_with_responses.each do |action, resp_code|
        if RETRYABLE_CODES.include?(resp_code)
          @logger.warn "retrying failed action with response code: #{resp_code}"
          actions_to_retry << action
        elsif not SUCCESS_CODES.include?(resp_code)
          @logger.warn "failed action with response of #{resp_code}, dropping action: #{action}"
        end
      end
      retry_push(actions_to_retry) unless actions_to_retry.empty?
    end
  end

  # When there are exceptions raised upon submission, we raise an exception so that
  # Stud::Buffer will retry to flush
  public
  def flush(actions, teardown = false)
    begin
      submit(actions)
    rescue => e
      @logger.error "Got error to send bulk of actions: #{e.message}"
      raise e
    ensure
      unless @protocol == "node"
        @logger.debug? and @logger.debug "Shifting current elasticsearch client"
        shift_client
      end
    end
  end # def flush

  public
  def teardown
    if @cacert # remove temporary jks store created from the cacert
      File.delete(@truststore)
    end

    @retry_teardown_requested.make_true
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

  protected
  def start_local_elasticsearch
    @logger.info("Starting embedded Elasticsearch local node.")
    builder = org.elasticsearch.node.NodeBuilder.nodeBuilder
    # Disable 'local only' - LOGSTASH-277
    #builder.local(true)
    builder.settings.put("cluster.name", @cluster) if @cluster
    builder.settings.put("node.name", @node_name) if @node_name
    builder.settings.put("network.host", @bind_host) if @bind_host
    builder.settings.put("http.port", @embedded_http_port)

    @embedded_elasticsearch = builder.node
    @embedded_elasticsearch.start
  end # def start_local_elasticsearch

  protected
  def shift_client
    @client_idx = (@client_idx+1) % @client.length
    @current_client = @client[@client_idx]
    @logger.debug? and @logger.debug("Switched current elasticsearch client to ##{@client_idx} at #{@host[@client_idx]}")
  end

  private
  def setup_proxy
    return {} unless @proxy

    if @protocol != "http"
      raise(LogStash::ConfigurationError, "Proxy is not supported for '#{@protocol}'. Change the protocol to 'http' if you need HTTP proxy.")
    end

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
    if @protocol != "http"
      raise(LogStash::ConfigurationError, "SSL is not supported for '#{@protocol}'. Change the protocol to 'http' if you need SSL.")
    end
    @protocol = "https"
    if @cacert && @truststore
      raise(LogStash::ConfigurationError, "Use either \"cacert\" or \"truststore\" when configuring the CA certificate") if @truststore
    end
    ssl_options = {}
    if @cacert then
      @truststore, ssl_options[:truststore_password] = generate_jks @cacert
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

    if @protocol =~ /http/
      {
        :user => ::URI.escape(@user, "@:"),
        :password => ::URI.escape(@password.value, "@:")
      }
    else
      raise(LogStash::ConfigurationError, "User and password parameters are not supported for '#{@protocol}'. Change the protocol to 'http' if you need them.")
    end
  end

  private
  def generate_jks cert_path

    require 'securerandom'
    require 'tempfile'
    require 'java'
    import java.io.FileInputStream
    import java.io.FileOutputStream
    import java.security.KeyStore
    import java.security.cert.CertificateFactory

    jks = java.io.File.createTempFile("cert", ".jks")

    ks = KeyStore.getInstance "JKS"
    ks.load nil, nil
    cf = CertificateFactory.getInstance "X.509"
    cert = cf.generateCertificate FileInputStream.new(cert_path)
    ks.setCertificateEntry "cacert", cert
    pwd = SecureRandom.urlsafe_base64(9)
    ks.store FileOutputStream.new(jks), pwd.to_java.toCharArray
    [jks.path, pwd]
  end

  private
  # in charge of submitting any actions in @retry_queue that need to be 
  # retried
  #
  # This method is not called concurrently. It is only called by @retry_thread
  # and once that thread is ended during the teardown process, a final call 
  # to this method is done upon teardown in the main thread.
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
