require 'manticore'

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
      
      # Create a new SafeURI that we can modify
      if path && path != "/"
        url_with_path = ::LogStash::Util::SafeURI.new(url.uri.clone)
        url_with_path.path = url.path + (path.start_with?("/") ? path : "/#{path}")
      else
        url_with_path = url
      end

      if url_with_path.user
        params[:auth] = { :user => url_with_path.user, :pass => url_with_path.password }
        url_with_path.user = nil
        url_with_path.password = nil
      end

      resp = @manticore.send(method.downcase, url_with_path.to_s, params)

      # Manticore returns lazy responses by default
      # We want to block for our usage, this will wait for the repsonse
      # to finish
      resp.call

      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      if resp.code < 200 || resp.code > 299 && resp.code != 404
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(resp.code, url_with_path, body)
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
