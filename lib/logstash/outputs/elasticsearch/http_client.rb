require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require 'logstash/outputs/elasticsearch/http_client/pool'
require 'logstash/outputs/elasticsearch/http_client/manticore_adapter'

module LogStash; module Outputs; class ElasticSearch;
  class HttpClient
    attr_reader :client, :options, :logger, :pool, :action_count, :recv_count
    # This is here in case we use DEFAULT_OPTIONS in the future
    # DEFAULT_OPTIONS = {
    #   :setting => value
    # }

    def initialize(options={})
      @logger = options[:logger]
      # Again, in case we use DEFAULT_OPTIONS in the future, uncomment this.
      # @options = DEFAULT_OPTIONS.merge(options)
      @options = options
      @pool = build_pool(@options)
      # mutex to prevent requests and sniffing to access the
      # connection pool at the same time
    end

    def template_install(name, template, force=false)
      if template_exists?(name) && !force
        @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
        return
      end
      template_put(name, template)
    end

    def get_version
      url, response = @pool.get("")
      LogStash::Json.load(response.body)["version"]
    end

    def bulk(actions)
      @action_count ||= 0
      @action_count += actions.size
      
      return if actions.empty?
      bulk_body = actions.collect do |action, args, source|
        args, source = update_action_builder(args, source) if action == 'update'

        if source && action != 'delete'
          next [ { action => args }, source ]
        else
          next { action => args }
        end
      end.
      flatten.
      reduce("") do |acc,line|
        acc << LogStash::Json.dump(line)
        acc << "\n"
      end

      # Discard the URL
      url, response = @pool.post("_bulk", nil, bulk_body)
      LogStash::Json.load(response.body)
    end

    def close
      @pool.close
    end

    private

    #
    # The `options` is a hash where the following symbol keys have meaning:
    #
    # * `:hosts` - array of String. Set a list of hosts to use for communication.
    # * `:port` - number. set the port to use to communicate with Elasticsearch
    # * `:user` - String. The user to use for authentication.
    # * `:password` - String. The password to use for authentication.
    # * `:timeout` - Float. A duration value, in seconds, after which a socket
    #    operation or request will be aborted if not yet successfull
    # * `:client_settings` - a hash; see below for keys.
    #
    # The `client_settings` key is a has that can contain other settings:
    #
    # * `:ssl` - Boolean. Enable or disable SSL/TLS.
    # * `:proxy` - String. Choose a HTTP HTTProxy to use.
    # * `:path` - String. The leading path for prefixing Elasticsearch
    #   requests. This is sometimes used if you are proxying Elasticsearch access
    #   through a special http path, such as using mod_rewrite.
    def build_pool(options)
      hosts = options[:hosts] || ["127.0.0.1"]
      client_settings = options[:client_settings] || {}
      timeout = options[:timeout] || 0

      host_ssl_opt = client_settings[:ssl].nil? ? nil : client_settings[:ssl][:enabled]
      urls = hosts.map {|host| host_to_url(host, host_ssl_opt, client_settings[:path])}

      adapter_options = {
        :socket_timeout => timeout,
        :request_timeout => timeout,
      }

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

      adapter_options[:ssl] = client_settings[:ssl] if client_settings[:ssl]

      if options[:user]
        adapter_options[:auth] = {
          :user => options[:user],
          :password => options[:password],
          :eager => true
        }
      end

      adapter_class = ::LogStash::Outputs::ElasticSearch::HttpClient::ManticoreAdapter
      adapter = adapter_class.new(@logger, adapter_options)

      pool_options = {
        :sniffing => options[:sniffing],
        :sniffer_delay => options[:sniffer_delay],
        :healthcheck_path => options[:healthcheck_path],
        :resurrect_delay => options[:resurrect_delay]
      }

      ssl_options = options[:client_settings] ? options[:client_settings][:ssl] : {}
      pool_options[:scheme] = ssl_options && ssl_options[:enabled] ? 'https' : 'http'

      if options[:user]
        pool_options[:auth] = {:user => options[:user], :password => options[:password]}
      end

      pool_class = ::LogStash::Outputs::ElasticSearch::HttpClient::Pool
      pool_class.new(@logger, adapter, urls, pool_options)
    end

    HOSTNAME_PORT_REGEX=/\A(?<hostname>([A-Za-z0-9\.\-]+)|\[[0-9A-Fa-f\:]+\])(:(?<port>\d+))?\Z/
    URL_REGEX=/\A#{URI::regexp(['http', 'https'])}\z/
    # Parse a configuration host to a normalized URL
    def host_to_url(host, ssl=nil, path=nil)
      explicit_scheme = case ssl
                        when true
                          "https"
                        when false
                          "http"
                        when nil
                          nil
                        else
                          raise ArgumentError, "Unexpected SSL value!"
                        end

      # Ensure path starts with a /
      if path && path[0] != '/'
        path = "/#{path}"
      end

      url = nil
      if host =~ URL_REGEX
        url = URI.parse(host)

        # Please note that the ssl == nil case is different! If you didn't make an explicit
        # choice we don't complain!
        if url.scheme == "http" && ssl == true
          raise LogStash::ConfigurationError, "You specified a plain 'http' URL '#{host}' but set 'ssl' to true! Aborting!"
        elsif url.scheme == "https" && ssl == false
          raise LogStash::ConfigurationError, "You have explicitly disabled SSL but passed in an https URL '#{host}'! Aborting!"
        end

        url.scheme = explicit_scheme if explicit_scheme
      elsif (match_results = HOSTNAME_PORT_REGEX.match(host))
        hostname = match_results["hostname"]
        port = match_results["port"] || 9200
        url = URI.parse("#{explicit_scheme || 'http'}://#{hostname}:#{port}")
      else
        raise LogStash::ConfigurationError, "Host '#{host}' was specified, but is not valid! Use either a full URL or a hostname:port string!"
      end

      if path && url.path && url.path != "/" && url.path != ''
        safe_url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
        raise LogStash::ConfigurationError, "A path '#{url.path}' has been explicitly specified in the url '#{safe_url}', but you also specified a path of '#{path}'. This is probably a mistake, please remove one setting."
      end

      if path
        url.path = path  # The URI library cannot stringify if it holds a nil
      end

      if url.password || url.user
        raise LogStash::ConfigurationError, "We do not support setting the user password in the URL directly as " +
          "this may be logged to disk thus leaking credentials. Use the 'user' and 'password' options respectively"
      end

      url
    end

    def template_exists?(name)
      url, response = @pool.head("/_template/#{name}")
      response.code >= 200 && response.code <= 299
    end

    def template_put(name, template)
      path = "_template/#{name}"
      logger.info("Installing elasticsearch template to #{path}")
      url, response = @pool.put(path, nil, LogStash::Json.dump(template))
      response
    end

    # Build a bulk item for an elasticsearch update action
    def update_action_builder(args, source)
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
