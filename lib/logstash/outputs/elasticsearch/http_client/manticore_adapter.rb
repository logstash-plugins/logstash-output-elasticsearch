require 'manticore'
require "logstash/outputs/elasticsearch/safe_url"

module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  class ManticoreAdapter
    attr_reader :manticore, :logger

    def initialize(logger, options={})
      @logger = logger
      @options = options || {}
      @options[:ssl] = @options[:ssl] || {}

      # We manage our own retries directly, so let's disable them here
      @options[:automatic_retries] = 0
      # We definitely don't need cookies
      @options[:cookies] = false

      @request_options = @options[:headers] ? {:headers => @options[:headers]} : {}
      @manticore = ::Manticore::Client.new(@options)
    end

    def client
      @manticore
    end

    # Performs the request by invoking {Transport::Base#perform_request} with a block.
    #
    # @return [Response]
    # @see    Transport::Base#perform_request
    #
    def perform_request(url, method, path, params={}, body=nil)
      params = (params || {}).merge @request_options
      params[:body] = body if body
      url_and_path = (url + path).to_s # Convert URI object to string

      resp = @manticore.send(method.downcase, url_and_path, params)

      # Manticore returns lazy responses by default
      # We want to block for our usage, this will wait for the repsonse
      # to finish
      resp.call

      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      if resp.code < 200 || resp.code > 299 && resp.code != 404
        safe_url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(resp.code, safe_url + path, body)
      end

      resp
    end

    def close
      @manticore.close
    end

    def host_unreachable_exceptions
      [::Manticore::Timeout,::Manticore::SocketException, ::Manticore::ClientProtocolException, ::Manticore::ResolutionFailure, Manticore::SocketTimeout]
    end
  end
end; end; end; end
