require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require "elasticsearch"
require "elasticsearch/transport/transport/http/manticore"

module LogStash::Outputs::Elasticsearch
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
      start_sniffing!
    end

    def template_install(name, template, force=false)
      if template_exists?(name) && !force
        @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
        return
      end
      template_put(name, template)
    end

    def bulk(actions)
      bulk_body = actions.collect do |action, args, source|
        if action == 'update'
          if args[:_id]
            source = { 'doc' => source }
            if @options[:doc_as_upsert]
              source['doc_as_upsert'] = true
            else
              source['upsert'] = args[:_upsert] if args[:_upsert]
            end
          else
            raise(LogStash::ConfigurationError, "Specifying action => 'update' without a document '_id' is not supported.")
          end
        end

        args.delete(:_upsert)

        if source
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
            sniff!
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

    def build_client(options)
      hosts = options[:hosts] || ["127.0.0.1"]
      client_settings = options[:client_settings] || {}

      uris = hosts.map do |host|
        proto = client_settings[:ssl] ? "https"  : "http"
        if host =~ /:\d+\z/
          "#{proto}://#{host}#{client_settings[:path]}"
        else
          # Use default port of 9200 if none provided with host.
          "#{proto}://#{host}:9200#{client_settings[:path]}"
        end
      end

      @client_options = {
        :hosts => uris,
        :ssl => client_settings[:ssl],
        :transport_options => {  # manticore settings so we
          :socket_timeout => 0,  # do not timeout socket reads
          :request_timeout => 0,  # and requests
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

    def template_exists?(name)
      @client.indices.get_template(:name => name)
      return true
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      return false
    end

    def template_put(name, template)
      @client.indices.put_template(:name => name, :body => template)
    end
  end
end
