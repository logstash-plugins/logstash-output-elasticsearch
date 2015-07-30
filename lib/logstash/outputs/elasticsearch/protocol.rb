require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require "elasticsearch"
require "elasticsearch/transport/transport/http/manticore"

module LogStash::Outputs::Elasticsearch
  module Protocols
    class Base
      private
      def initialize(options={})
        # host(s), port, cluster
        @logger = Cabin::Channel.get
      end

      def client
        return @client if @client
        @client = build_client(@options)
        return @client
      end # def client


      def template_install(name, template, force=false)
        if template_exists?(name) && !force
          @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
          return
        end
        template_put(name, template)
      end

      # Do a bulk request with the given actions.
      #
      # 'actions' is expected to be an array of bulk requests as string json
      # values.
      #
      # Each 'action' becomes a single line in the bulk api call. For more
      # details on the format of each.
      def bulk(actions)
        raise NotImplemented, "You must implement this yourself"
        # bulk([
        # '{ "index" : { "_index" : "test", "_type" : "type1", "_id" : "1" } }',
        # '{ "field1" : "value1" }'
        #])
      end

      public(:initialize, :template_install)
    end

    class HTTPClient < Base
      private

      DEFAULT_OPTIONS = {
        :port => 9200
      }

      def initialize(options={})
        super
        @options = DEFAULT_OPTIONS.merge(options)
        @client = client
      end

      def build_client(options)
        uri = "http://#{options[:host]}:#{options[:port]}#{options[:client_settings][:path]}"

        client_options = {
          :host => [uri],
          :ssl => options[:client_settings][:ssl],
          :transport_options => {  # manticore settings so we
            :socket_timeout => 0,  # do not timeout socket reads
            :request_timeout => 0,  # and requests
            :proxy => options[:client_settings][:proxy]
          },
          :transport_class => ::Elasticsearch::Transport::Transport::HTTP::Manticore
        }

        if options[:user] && options[:password] then
          token = Base64.strict_encode64(options[:user] + ":" + options[:password])
          client_options[:headers] = { "Authorization" => "Basic #{token}" }
        end

        Elasticsearch::Client.new client_options
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

      def bulk(actions)
        bulk_response = @client.bulk(:body => actions.collect do |action, args, source|
          if source
            next [ { action => args }, source ]
          else
            next { action => args }
          end
        end.flatten)

        self.class.normalize_bulk_response(bulk_response)
      end # def bulk

      def template_exists?(name)
        @client.indices.get_template(:name => name)
        return true
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return false
      end # def template_exists?

      def template_put(name, template)
        @client.indices.put_template(:name => name, :body => template)
      end # template_put

      public(:bulk)
    end # class HTTPClient
  end # module Protocols

  module Requests
    class GetIndexTemplates; end
    class Bulk; end
    class Index; end
    class Delete; end
  end
end
