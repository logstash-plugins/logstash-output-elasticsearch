require 'manticore'
require 'cgi'

module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  DEFAULT_HEADERS = { "Content-Type" => "application/json" }
  
  class ManticoreAdapter
    attr_reader :manticore, :logger

    def initialize(logger, options={})
      @logger = logger
      options = options.clone || {}
      options[:ssl] = options[:ssl] || {}

      # We manage our own retries directly, so let's disable them here
      options[:automatic_retries] = 0
      # We definitely don't need cookies
      options[:cookies] = false

      @client_params = {:headers => DEFAULT_HEADERS.merge(options[:headers] || {})}
      
      if options[:proxy]
        options[:proxy] = manticore_proxy_hash(options[:proxy])
      end
      
      @manticore = ::Manticore::Client.new(options)
    end
    
    # Transform the proxy option to a hash. Manticore's support for non-hash
    # proxy options is broken. This was fixed in https://github.com/cheald/manticore/commit/34a00cee57a56148629ed0a47c329181e7319af5
    # but this is not yet released
    def manticore_proxy_hash(proxy_uri)
      [:scheme, :port, :user, :password, :path].reduce(:host => proxy_uri.host) do |acc,opt|
        value = proxy_uri.send(opt)
        acc[opt] = value unless value.nil? || (value.is_a?(String) && value.empty?)
        acc
      end
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
      params = (params || {}).merge(@client_params)
      params[:body] = body if body

      if url.user
        params[:auth] = { 
          :user => url.user,
          # We have to unescape the password here since manticore won't do it
          # for us unless its part of the URL
          :password => CGI.unescape(url.password), 
          :eager => true 
        }
      end

      request_uri = format_url(url, path)

      resp = @manticore.send(method.downcase, request_uri.to_s, params)

      # Manticore returns lazy responses by default
      # We want to block for our usage, this will wait for the repsonse
      # to finish
      resp.call

      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      if resp.code < 200 || resp.code > 299 && resp.code != 404
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(resp.code, request_uri, body, resp.body)
      end

      resp
    end

    def format_url(url, path)

      request_uri = url.uri

      if path
        # Combine the paths using the minimal # of /s
        # First, we make sure the path is relative so URI.join does
        # the right thing
        relative_path = path && path.start_with?("/") ? path[1..-1] : path
        # because URI.join obliterates the query parameter, we need to save it
        # and restore it after this operation
        query = request_uri.query
        request_uri = URI.join(request_uri, relative_path)
        request_uri.query = query
      else
        request_uri = request_uri.clone
      end

      # We excise auth info from the URL in case manticore itself tries to stick
      # sensitive data in a thrown exception or log data
      request_uri.user = nil
      request_uri.password = nil

      # Wrap this with a safe URI defensively against careless handling later
      ::LogStash::Util::SafeURI.new(request_uri)
    end

    def close
      @manticore.close
    end

    def host_unreachable_exceptions
      [::Manticore::Timeout,::Manticore::SocketException, ::Manticore::ClientProtocolException, ::Manticore::ResolutionFailure, Manticore::SocketTimeout]
    end
  end
end; end; end; end
