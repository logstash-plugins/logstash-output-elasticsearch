require "logstash/outputs/elasticsearch"
require "cabin"
require "base64"
require "elasticsearch"
require "elasticsearch/transport/transport/http/manticore"

module LogStash::Outputs::Elasticsearch
  class HTTPClient
    attr_reader :client
    DEFAULT_OPTIONS = {
      :port => 9200
    }

    def initialize(options={})
      @logger = Cabin::Channel.get
      @options = DEFAULT_OPTIONS.merge(options)
      @client = build_client(@options)
    end

    def template_install(name, template, force=false)
      if template_exists?(name) && !force
        @logger.debug("Found existing Elasticsearch template. Skipping template management", :name => name)
        return
      end
      template_put(name, template)
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
    end

    private

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
