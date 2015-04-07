require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"

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
        require "elasticsearch" # gem 'elasticsearch-ruby'
        # manticore http transport
        require "elasticsearch/transport/transport/http/manticore"
        @options = DEFAULT_OPTIONS.merge(options)
        @client = client
      end

      def build_client(options)
        uri = "#{options[:protocol]}://#{options[:host]}:#{options[:port]}"

        client_options = {
          :host => [uri],
          :transport_options => options[:client_settings]
        }
        client_options[:transport_class] = ::Elasticsearch::Transport::Transport::HTTP::Manticore
        client_options[:ssl] = client_options[:transport_options].delete(:ssl)

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

    class NodeClient < Base
      private

      DEFAULT_OPTIONS = {
        :port => 9300,
      }

      def initialize(options={})
        super
        require "java"
        @options = DEFAULT_OPTIONS.merge(options)
        setup(@options)
        @client = client
      end # def initialize

      def settings
        return @settings
      end

      def setup(options={})
        @settings = org.elasticsearch.common.settings.ImmutableSettings.settingsBuilder
        if options[:host]
          @settings.put("discovery.zen.ping.multicast.enabled", false)
          @settings.put("discovery.zen.ping.unicast.hosts", hosts(options))
        end

        @settings.put("node.client", true)
        @settings.put("http.enabled", false)

        if options[:client_settings]
          options[:client_settings].each do |key, value|
            @settings.put(key, value)
          end
        end

        return @settings
      end

      def hosts(options)
        # http://www.elasticsearch.org/guide/reference/modules/discovery/zen/
        result = Array.new
        if options[:host].class == Array
          options[:host].each do |host|
            if host.to_s =~ /^.+:.+$/
              # For host in format: host:port, ignore options[:port]
              result << host
            else
              if options[:port].to_s =~ /^\d+-\d+$/
                # port ranges are 'host[port1-port2]'
                result << Range.new(*options[:port].split("-")).collect { |p| "#{host}:#{p}" }
              else
                result << "#{host}:#{options[:port]}"
              end
            end
          end
        else
          if options[:host].to_s =~ /^.+:.+$/
            # For host in format: host:port, ignore options[:port]
            result << options[:host]
          else
            if options[:port].to_s =~ /^\d+-\d+$/
              # port ranges are 'host[port1-port2]' according to
              # http://www.elasticsearch.org/guide/reference/modules/discovery/zen/
              # However, it seems to only query the first port.
              # So generate our own list of unicast hosts to scan.
              range = Range.new(*options[:port].split("-"))
              result << range.collect { |p| "#{options[:host]}:#{p}" }
            else
              result << "#{options[:host]}:#{options[:port]}"
            end
          end
        end
        result.flatten.join(",")
      end # def hosts

      def build_client(options)
        nodebuilder = org.elasticsearch.node.NodeBuilder.nodeBuilder
        return nodebuilder.settings(@settings).node.client
      end # def build_client

      def self.normalize_bulk_response(bulk_response)
        # TODO(talevy): parse item response objects to retrieve correct 200 (OK) or 201(created) status codes
        if bulk_response.has_failures()
          {"errors" => true,
           "statuses" => bulk_response.map { |i| (i.is_failed && i.get_failure.get_status.get_status) || 200 }}
        else
          {"errors" => false}
        end
      end

      def bulk(actions)
        # Actions an array of [ action, action_metadata, source ]
        prep = @client.prepareBulk
        actions.each do |action, args, source|
          prep.add(build_request(action, args, source))
        end
        response = prep.execute.actionGet()

        self.class.normalize_bulk_response(response)
      end # def bulk

      def build_request(action, args, source)
        case action
          when "index"
            request = org.elasticsearch.action.index.IndexRequest.new(args[:_index])
            request.id(args[:_id]) if args[:_id]
            request.routing(args[:_routing]) if args[:_routing]
            request.source(source)
          when "delete"
            request = org.elasticsearch.action.delete.DeleteRequest.new(args[:_index])
            request.id(args[:_id])
            request.routing(args[:_routing]) if args[:_routing]
          when "create"
            request = org.elasticsearch.action.index.IndexRequest.new(args[:_index])
            request.id(args[:_id]) if args[:_id]
            request.routing(args[:_routing]) if args[:_routing]
            request.source(source)
            request.opType("create")
          when "create_unless_exists"
            unless args[:_id].nil?
              request = org.elasticsearch.action.index.IndexRequest.new(args[:_index])
              request.id(args[:_id])
              request.routing(args[:_routing]) if args[:_routing]
              request.source(source)
              request.opType("create")
            else
              raise(LogStash::ConfigurationError, "Specifying action => 'create_unless_exists' without a document '_id' is not supported.")
            end
          else
            raise(LogStash::ConfigurationError, "action => '#{action_name}' is not currently supported.")
          #when "update"
        end # case action

        request.type(args[:_type]) if args[:_type]
        return request
      end # def build_request

      def template_exists?(name)
        request = org.elasticsearch.action.admin.indices.template.get.GetIndexTemplatesRequestBuilder.new(@client.admin.indices, name)
        response = request.get
        return !response.getIndexTemplates.isEmpty
      end # def template_exists?

      def template_put(name, template)
        request = org.elasticsearch.action.admin.indices.template.put.PutIndexTemplateRequestBuilder.new(@client.admin.indices, name)
        request.setSource(LogStash::Json.dump(template))

        # execute the request and get the response, if it fails, we'll get an exception.
        request.get
      end # template_put

      public(:initialize, :bulk)
    end # class NodeClient

    class TransportClient < NodeClient
      private
      def build_client(options)
        client = org.elasticsearch.client.transport.TransportClient.new(settings.build)

        if options[:host]
          client.addTransportAddress(
            org.elasticsearch.common.transport.InetSocketTransportAddress.new(
              options[:host], options[:port].to_i
            )
          )
        end

        return client
      end # def build_client
    end # class TransportClient
  end # module Protocols

  module Requests
    class GetIndexTemplates; end
    class Bulk; end
    class Index; end
    class Delete; end
  end
end
