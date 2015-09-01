require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require "elasticsearch"
require "elasticsearch/transport/transport/http/manticore"

module LogStash::Outputs::Elasticsearch
  class HttpClient
    attr_reader :client, :options, :client_options, :sniffer_thread
    DEFAULT_OPTIONS = {
      :port => 9200
    }

    def initialize(options={})
      @logger = Cabin::Channel.get
      @options = DEFAULT_OPTIONS.merge(options)
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

      bulk_response = @client.bulk(:body => bulk_body)

      self.class.normalize_bulk_response(bulk_response)
    end

    def start_sniffing!
      if options[:sniffing]
        @sniffer_thread = Thread.new do
          loop do
            sniff!
            sleep (options[:sniffing_delay] || 30)
          end
        end
      end
    end

    def stop_sniffing!
      @sniffer_thread.kill() if @sniffer_thread
    end

    def sniff!
      client.transport.reload_connections! if options[:sniffing]
    rescue StandardError => e
      @logger.error("Error while sniffing connection",
                    :message => e.message,
                    :class => e.class.name)
    end

    private

    def build_client(options)
      hosts = options[:hosts] || ["127.0.0.1"]
      port = options[:port] || 9200
      client_settings = options[:client_settings] || {}

      uris = hosts.map do |host|
        "http://#{host}:#{port}#{client_settings[:path]}"
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

      Elasticsearch::Client.new(client_options)
    end

    def self.normalize_bulk_response(bulk_response)
      if bulk_response["errors"]
        # The structure of the response from the REST Bulk API is follows:
        # {"took"=>74, "errors"=>true, "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
        #                                                    "_type"=>"logs",
        #                                                    "_id"=>"AUxTS2C55Jrgi-hC6rQF",
        #                                                    "_version"=>1,
        #                                                    "status"=>400,
        #                                                    "error"=>"MapperParsingException[failed to parse]..."}}]}
        # where each `item` is a hash of {OPTYPE => Hash[]}. calling first, will retrieve
        # this hash as a single array with two elements, where the value is the second element (i.first[1])
        # then the status of that item is retrieved.
        {"errors" => true, "statuses" => bulk_response["items"].map { |i| i.first[1]['status'] }}
      else
        {"errors" => false}
      end
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
