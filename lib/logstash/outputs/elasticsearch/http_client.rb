require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require "elasticsearch"
require "elasticsearch/transport/transport/http/manticore"

module LogStash; module Outputs; class ElasticSearch;
  class HttpClient
    attr_reader :client, :options, :client_options, :sniffer_thread
    # This is here in case we use DEFAULT_OPTIONS in the future
    # DEFAULT_OPTIONS = {
    #   :setting => value
    # }

    def initialize(options={})
      @logger = options[:logger]
      # Again, in case we use DEFAULT_OPTIONS in the future, uncomment this.
      # @options = DEFAULT_OPTIONS.merge(options)
      @options = options
      @client = build_client(@options)
      # mutex to prevent requests and sniffing to access the
      # connection pool at the same time
      @request_mutex = Mutex.new
      start_sniffing!
    end

    def template_install(name, template, force=false)
      @request_mutex.synchronize do
        if template_exists?(name) && !force
          @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
          return
        end
        template_put(name, template)
      end
    end

    def bulk(actions)
      @request_mutex.synchronize { non_threadsafe_bulk(actions) }
    end

    def non_threadsafe_bulk(actions)
      return if actions.empty?
      bulk_body = actions.collect do |action, args, source|
        args, source = update_action_builder(args, source) if action == 'update'

        if source && action != 'delete'
          next [ { action => args }, source ]
        else
          next { action => args }
        end
      end.flatten

      @client.bulk(:body => bulk_body)
    end

    def start_sniffing!
      if options[:sniffing]
        @sniffer_thread = Thread.new do
          loop do
            @request_mutex.synchronize { sniff! }
            sleep (options[:sniffing_delay].to_f || 30)
          end
        end
      end
    end

    def stop_sniffing!
      @sniffer_thread.kill() if @sniffer_thread
    end

    def sniff!
      client.transport.reload_connections! if options[:sniffing]
      hosts_by_name = client.transport.hosts.map {|h| h["name"]}.sort
      @logger.debug({"count" => hosts_by_name.count, "hosts" => hosts_by_name})
    rescue StandardError => e
      @logger.error("Error while sniffing connection",
                    :message => e.message,
                    :class => e.class.name,
                    :backtrace => e.backtrace)
    end

    private

    # Builds a client and returns an Elasticsearch::Client
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
    def build_client(options)
      hosts = options[:hosts] || ["127.0.0.1"]
      client_settings = options[:client_settings] || {}
      timeout = options[:timeout] || 0

      urls = hosts.map {|host| host_to_url(host, client_settings[:ssl], client_settings[:path])}

      @client_options = {
        :hosts => urls,
        :ssl => client_settings[:ssl],
        :transport_options => {
          :socket_timeout => timeout,
          :request_timeout => timeout,
          :proxy => client_settings[:proxy]
        },
        :transport_class => ::Elasticsearch::Transport::Transport::HTTP::Manticore
      }

      if options[:user] && options[:password] then
        token = Base64.strict_encode64(options[:user] + ":" + options[:password])
        @client_options[:headers] = { "Authorization" => "Basic #{token}" }
      end

      @logger.debug? && @logger.debug("Elasticsearch HTTP client options", client_options)

      Elasticsearch::Client.new(client_options)
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
                        else
                          nil
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
        raise LogStash::ConfigurationError, "A path '#{url.path}' has been explicitly specified in the url '#{url}', but you also specified a path of '#{path}'. This is probably a mistake, please remove one setting."
      end

      if path
        url.path = path  # The URI library cannot stringify if it holds a nil
      end

      if url.password || url.user
        raise LogStash::ConfigurationError, "We do not support setting the user password in the URL directly as " +
          "this may be logged to disk thus leaking credentials. Use the 'user' and 'password' options respectively"
      end

      url.to_s
    end

    def template_exists?(name)
      @client.indices.get_template(:name => name)
      return true
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      return false
    end

    def template_put(name, template)
      @client.indices.put_template(:name => name, :body => template)
    end

    # Build a bulk item for an elasticsearch update action
    def update_action_builder(args, source)
      if args[:_script]
        # Use the event as a hash from your script with variable name defined
        # by script_var_name (default: "event")
        # Ex: event["@timestamp"]
        source = { 'script' => {'params' => { @options[:script_var_name] => source }} }
        if @options[:scripted_upsert]
          source['scripted_upsert'] = true
          source['upsert'] = {}
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
