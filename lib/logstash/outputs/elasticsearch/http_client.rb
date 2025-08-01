require "logstash/outputs/elasticsearch"
require 'logstash/outputs/elasticsearch/http_client/pool'
require 'logstash/outputs/elasticsearch/http_client/manticore_adapter'
require 'cgi'
require 'zlib'
require 'stringio'
require 'java'

module LogStash; module Outputs; class ElasticSearch;
  # This is a constant instead of a config option because
  # there really isn't a good reason to configure it.
  #
  # The criteria used are:
  # 1. We need a number that's less than 100MiB because ES
  #    won't accept bulks larger than that.
  # 2. It must be large enough to amortize the connection constant
  #    across multiple requests.
  # 3. It must be small enough that even if multiple threads hit this size
  #    we won't use a lot of heap.
  #
  # We wound up agreeing that a number greater than 10 MiB and less than 100MiB
  # made sense. We picked one on the lowish side to not use too much heap.
  TARGET_BULK_BYTES = 20 * 1024 * 1024 # 20MiB
  EVENT_COUNT_HEADER = "X-Elastic-Event-Count".freeze
  UNCOMPRESSED_LENGTH_HEADER = "X-Elastic-Uncompressed-Request-Length".freeze

  class HttpClient
    attr_reader :client, :options, :logger, :pool, :action_count, :recv_count
    # This is here in case we use DEFAULT_OPTIONS in the future
    # DEFAULT_OPTIONS = {
    #   :setting => value
    # }

#
    # The `options` is a hash where the following symbol keys have meaning:
    #
    # * `:hosts` - array of String. Set a list of hosts to use for communication.
    # * `:port` - number. set the port to use to communicate with Elasticsearch
    # * `:user` - String. The user to use for authentication.
    # * `:password` - String. The password to use for authentication.
    # * `:timeout` - Float. A duration value, in seconds, after which a socket
    #    operation or request will be aborted if not yet successful
    # * `:client_settings` - a hash; see below for keys.
    #
    # The `client_settings` key is a has that can contain other settings:
    #
    # * `:ssl` - Boolean. Enable or disable SSL/TLS.
    # * `:proxy` - String. Choose a HTTP HTTProxy to use.
    # * `:path` - String. The leading path for prefixing Elasticsearch
    # * `:headers` - Hash. Pairs of headers and their values
    #   requests. This is sometimes used if you are proxying Elasticsearch access
    #   through a special http path, such as using mod_rewrite.
    def initialize(options={})
      @logger = options[:logger]
      @metric = options[:metric]
      @bulk_request_metrics = @metric.namespace(:bulk_requests)
      @bulk_response_metrics = @bulk_request_metrics.namespace(:responses)

      # Again, in case we use DEFAULT_OPTIONS in the future, uncomment this.
      # @options = DEFAULT_OPTIONS.merge(options)
      @options = options

      @url_template = build_url_template

      @pool = build_pool(@options)
      # mutex to prevent requests and sniffing to access the
      # connection pool at the same time
      @bulk_path = @options[:bulk_path]
    end

    def build_url_template
      {
        :scheme => self.scheme,
        :user => self.user,
        :password => self.password,
        :host => "URLTEMPLATE",
        :port => self.port,
        :path => self.path
      }
    end

    def template_install(template_endpoint, name, template, force=false)
      if template_exists?(template_endpoint, name) && !force
        @logger.debug("Found existing Elasticsearch template, skipping template management", name: name)
        return
      end
      template_put(template_endpoint, name, template)
    end

    def last_es_version
      @pool.last_es_version
    end

    def maximum_seen_major_version
      @pool.maximum_seen_major_version
    end

    def serverless?
      @pool.serverless?
    end

    def alive_urls_count
      @pool.alive_urls_count
    end

    def bulk(actions)
      @action_count ||= 0
      @action_count += actions.size

      return if actions.empty?

      bulk_actions = actions.collect do |action, args, source|
        args, source = update_action_builder(args, source) if action == 'update'

        if source && action != 'delete'
          next [ { action => args }, source ]
        else
          next { action => args }
        end
      end

      body_stream = StringIO.new
      if compression_level?
        body_stream.set_encoding "BINARY"
        stream_writer = gzip_writer(body_stream)
      else
        stream_writer = body_stream
      end

      bulk_responses = []
      batch_actions = []
      bulk_actions.each_with_index do |action, index|
        as_json = action.is_a?(Array) ?
                    action.map {|line| LogStash::Json.dump(line)}.join("\n") :
                    LogStash::Json.dump(action)
        as_json << "\n"

        as_json.scrub! # ensure generated JSON is valid UTF-8

        if (stream_writer.pos + as_json.bytesize) > TARGET_BULK_BYTES && stream_writer.pos > 0
          stream_writer.flush # ensure writer has sync'd buffers before reporting sizes
          logger.debug("Sending partial bulk request for batch with one or more actions remaining.",
                       :action_count => batch_actions.size,
                       :payload_size => stream_writer.pos,
                       :content_length => body_stream.size,
                       :batch_offset => (index + 1 - batch_actions.size))
          headers = {
            EVENT_COUNT_HEADER => batch_actions.size.to_s,
            UNCOMPRESSED_LENGTH_HEADER => stream_writer.pos.to_s
          }
          bulk_responses << bulk_send(body_stream, batch_actions, headers)
          body_stream.truncate(0) && body_stream.seek(0)
          stream_writer = gzip_writer(body_stream) if compression_level?
          batch_actions.clear
        end
        stream_writer.write(as_json)
        batch_actions << action
      end

      stream_writer.close if compression_level?

      logger.debug("Sending final bulk request for batch.",
                   :action_count => batch_actions.size,
                   :payload_size => stream_writer.pos,
                   :content_length => body_stream.size,
                   :batch_offset => (actions.size - batch_actions.size))

      if body_stream.size > 0
        headers = {
          EVENT_COUNT_HEADER => batch_actions.size.to_s,
          UNCOMPRESSED_LENGTH_HEADER => stream_writer.pos.to_s
        }
        bulk_responses << bulk_send(body_stream, batch_actions, headers)
      end

      body_stream.close unless compression_level?
      join_bulk_responses(bulk_responses)
    end

    def gzip_writer(io)
      fail(ArgumentError, "Cannot create gzip writer on IO with unread bytes") unless io.eof?
      fail(ArgumentError, "Cannot create gzip writer on non-empty IO") unless io.pos == 0

      Zlib::GzipWriter.new(io, client_settings.fetch(:compression_level), Zlib::DEFAULT_STRATEGY)
    end

    def join_bulk_responses(bulk_responses)
      {
        "errors" => bulk_responses.any? {|r| r["errors"] == true},
        "items" => bulk_responses.reduce([]) {|m,r| m.concat(r.fetch("items", []))}
      }
    end

    def bulk_send(body_stream, batch_actions, headers = {})
      params = compression_level? ? {:headers => headers.merge("Content-Encoding" => "gzip") } : { :headers => headers }

      begin
        response = @pool.post(@bulk_path, params, body_stream.string)
        @bulk_response_metrics.increment(response.code.to_s)
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        @bulk_response_metrics.increment(e.response_code.to_s)
        raise e unless e.response_code == 413
        # special handling for 413, treat it as a document level issue
        logger.warn("Bulk request rejected: `413 Payload Too Large`", :action_count => batch_actions.size, :content_length => body_stream.size)
        return emulate_batch_error_response(batch_actions, 413, 'payload_too_large')
      rescue => e # it may be a network issue instead, re-raise
        raise e
      end

      LogStash::Json.load(response.body)
    end

    def emulate_batch_error_response(actions, http_code, reason)
      {
          "errors" => true,
          "items" => actions.map do |action|
            action = action.first if action.is_a?(Array)
            request_action, request_parameters = action.first
            {
                request_action => {"status" => http_code, "error" => { "type" => reason }}
            }
          end
      }
    end

    def get(path)
      response = @pool.get(path)
      LogStash::Json.load(response.body)
    end

    def post(path, params = {}, body_string)
      response = @pool.post(path, params, body_string)
      LogStash::Json.load(response.body)
    end

    def close
      @pool.close
    end

    def calculate_property(uris, property, default, sniff_check)
      values = uris.map(&property).uniq

      if sniff_check && values.size > 1
        raise LogStash::ConfigurationError, "Cannot have multiple values for #{property} in hosts when sniffing is enabled!"
      end

      uri_value = values.first

      default = nil if default.is_a?(String) && default.empty? # Blanks are as good as nil
      uri_value = nil if uri_value.is_a?(String) && uri_value.empty?

      if default && uri_value && (default != uri_value)
        raise LogStash::ConfigurationError, "Explicit value for '#{property}' was declared, but it is different in one of the URLs given! Please make sure your URLs are inline with explicit values. The URLs have the property set to '#{uri_value}', but it was also set to '#{default}' explicitly"
      end

      uri_value || default
    end

    def sniffing
      @options[:sniffing]
    end

    def user
      calculate_property(uris, :user, @options[:user], sniffing)
    end

    def password
      calculate_property(uris, :password, @options[:password], sniffing)
    end

    def path
      calculated = calculate_property(uris, :path, client_settings[:path], sniffing)
      calculated = "/#{calculated}" if calculated && !calculated.start_with?("/")
      calculated
    end

    def scheme
      explicit_scheme = if ssl_options && ssl_options.has_key?(:enabled)
                          ssl_options[:enabled] ? 'https' : 'http'
                        else
                          nil
                        end
      
      calculated_scheme = calculate_property(uris, :scheme, explicit_scheme, sniffing)

      if calculated_scheme && calculated_scheme !~ /https?/
        raise LogStash::ConfigurationError, "Bad scheme '#{calculated_scheme}' found should be one of http/https"
      end

      if calculated_scheme && explicit_scheme && calculated_scheme != explicit_scheme
        raise LogStash::ConfigurationError, "SSL option was explicitly set to #{ssl_options[:enabled]} but a URL was also declared with a scheme of '#{explicit_scheme}'. Please reconcile this"
      end

      calculated_scheme # May be nil if explicit_scheme is nil!
    end

    def port
      # We don't set the 'default' here because the default is what the user
      # indicated, so we use an || outside of calculate_property. This lets people
      # Enter things like foo:123, bar and wind up with foo:123, bar:9200
      calculate_property(uris, :port, nil, sniffing) || 9200
    end
    
    def uris
      @options[:hosts]
    end

    def client_settings
      @_client_settings ||= @options[:client_settings] || {}
    end

    def ssl_options
      @_ssl_options ||= client_settings.fetch(:ssl, {})
    end

    # return true if compression_level is [1..9]
    # return false if it is 0
    def compression_level?
      client_settings.fetch(:compression_level) > 0
    end

    def build_adapter(options)
      timeout = options[:timeout] || 0
      
      adapter_options = {
        :socket_timeout => timeout,
        :request_timeout => timeout,
      }

      adapter_options[:user_agent] = prepare_user_agent

      adapter_options[:proxy] = client_settings[:proxy] if client_settings[:proxy]

      adapter_options[:check_connection_timeout] = client_settings[:check_connection_timeout] if client_settings[:check_connection_timeout]

      # Having this explicitly set to nil is an error
      if client_settings[:pool_max]
        adapter_options[:pool_max] = client_settings[:pool_max]
      end

      # Having this explicitly set to nil is an error
      if client_settings[:pool_max_per_route]
        adapter_options[:pool_max_per_route] = client_settings[:pool_max_per_route]
      end

      adapter_options[:ssl] = ssl_options if self.scheme == 'https'

      adapter_options[:headers] = client_settings[:headers] if client_settings[:headers]

      ::LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter.new(@logger, adapter_options)
    end

    def prepare_user_agent
      os_name = java.lang.System.getProperty('os.name')
      os_version = java.lang.System.getProperty('os.version')
      os_arch = java.lang.System.getProperty('os.arch')
      jvm_vendor = java.lang.System.getProperty('java.vendor')
      jvm_version = java.lang.System.getProperty('java.version')

      plugin_version = Gem.loaded_specs['logstash-output-elasticsearch'].version
      # example: Logstash/7.14.1 (OS=Linux-5.4.0-84-generic-amd64; JVM=AdoptOpenJDK-11.0.11) logstash-output-elasticsearch/11.0.1
      "Logstash/#{LOGSTASH_VERSION} (OS=#{os_name}-#{os_version}-#{os_arch}; JVM=#{jvm_vendor}-#{jvm_version}) logstash-output-elasticsearch/#{plugin_version}"
    end
    
    def build_pool(options)
      adapter = build_adapter(options)

      pool_options = {
        :license_checker => options[:license_checker],
        :sniffing => sniffing,
        :sniffer_delay => options[:sniffer_delay],
        :sniffing_path => options[:sniffing_path],
        :healthcheck_path => options[:healthcheck_path],
        :resurrect_delay => options[:resurrect_delay],
        :url_normalizer => self.method(:host_to_url),
        :metric => options[:metric]
      }
      pool_options[:scheme] = self.scheme if self.scheme

      pool_class = ::LogStash::Outputs::ElasticSearch::HttpClient::Pool
      full_urls = @options[:hosts].map {|h| host_to_url(h) }
      pool = pool_class.new(@logger, adapter, full_urls, pool_options)
      pool.start
      pool
    end

    def host_to_url(h)
      # Never override the calculated scheme
      raw_scheme = @url_template[:scheme] || 'http'

      raw_user = h.user || @url_template[:user]
      raw_password = h.password || @url_template[:password]
      postfixed_userinfo = raw_user && raw_password ? "#{raw_user}:#{raw_password}@" : nil

      raw_host = h.host # Always replace this!
      raw_port =  h.port || @url_template[:port]

      raw_path = !h.path.nil? && !h.path.empty? &&  h.path != "/" ? h.path : @url_template[:path]
      prefixed_raw_path = raw_path && !raw_path.empty? ? raw_path : "/"

      parameters = client_settings[:parameters]
      raw_query = if parameters && !parameters.empty?
                    combined = h.query ?
                      Hash[URI::decode_www_form(h.query)].merge(parameters) :
                      parameters
                    query_str = combined.flat_map {|k,v|
                      values = Array(v)
                      values.map {|av| "#{k}=#{av}"}
                    }.join("&")
                    query_str
                  else
                    h.query
                  end
      prefixed_raw_query = raw_query && !raw_query.empty? ? "?#{raw_query}" : nil
      
      raw_url = "#{raw_scheme}://#{postfixed_userinfo}#{raw_host}:#{raw_port}#{prefixed_raw_path}#{prefixed_raw_query}"

      ::LogStash::Util::SafeURI.new(raw_url)
    end

    def exists?(path, use_get=false)
      response = use_get ? @pool.get(path) : @pool.head(path)
      response.code >= 200 && response.code <= 299
    rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
      return false if e.response_code == 404
      raise e
    end

    def template_exists?(template_endpoint, name)
      exists?("/#{template_endpoint}/#{name}")
    end

    def template_put(template_endpoint, name, template)
      path = "#{template_endpoint}/#{name}"
      logger.info("Installing Elasticsearch template", name: name)
      @pool.put(path, nil, LogStash::Json.dump(template))
    rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
      raise e unless e.response_code == 404
    end

    # ILM methods

    # check whether rollover alias already exists
    def rollover_alias_exists?(name)
      exists?(name)
    end

    # Create a new rollover alias
    def rollover_alias_put(alias_name, alias_definition)
      @pool.put(CGI::escape(alias_name), nil, LogStash::Json.dump(alias_definition))
      logger.info("Created rollover alias", name: alias_name)
      # If the rollover alias already exists, ignore the error that comes back from Elasticsearch
    rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
      if e.response_code == 400
        logger.info("Rollover alias already exists, skipping", name: alias_name)
        return
      end
      raise e
    end

    def get_xpack_info
      get("/_xpack")
    end

    def get_ilm_endpoint
      @pool.get("/_ilm/policy")
    end

    def ilm_policy_exists?(name)
      exists?("/_ilm/policy/#{name}", true)
    end

    def ilm_policy_put(name, policy)
      path = "_ilm/policy/#{name}"
      logger.info("Installing ILM policy #{policy}", name: name)
      @pool.put(path, nil, LogStash::Json.dump(policy))
    end


    # Build a bulk item for an elasticsearch update action
    def update_action_builder(args, source)
      args = args.clone()
      if args[:_script]
        # Use the event as a hash from your script with variable name defined
        # by script_var_name (default: "event")
        # Ex: event["@timestamp"]
        source_orig = source
        source = { 'script' => {'params' => { @options[:script_var_name] => source_orig }} }
        if @options[:scripted_upsert]
          source['scripted_upsert'] = true
          source['upsert'] = {}
        elsif @options[:doc_as_upsert]
          source['upsert'] = source_orig
        else
          source['upsert'] = args.delete(:_upsert) if args[:_upsert]
        end
        case @options[:script_type]
        when 'indexed'
          source['script']['id'] = args.delete(:_script)
        when 'file'
          source['script']['file'] = args.delete(:_script)
        when 'inline'
          source['script']['inline'] = args.delete(:_script)
        end
        source['script']['lang'] = @options[:script_lang] if @options[:script_lang] != ''
      else
        source = { 'doc' => source }
        if @options[:doc_as_upsert]
          source['doc_as_upsert'] = true
        else
          source['upsert'] = args.delete(:_upsert) if args[:_upsert]
        end
      end
      [args, source]
    end

  end
end end end
