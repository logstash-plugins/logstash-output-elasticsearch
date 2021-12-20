require 'manticore'
require 'cgi'

module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  DEFAULT_HEADERS = { "Content-Type" => "application/json" }
  
  class ManticoreAdapter
    attr_reader :manticore, :logger

    def initialize(logger, options)
      @logger = logger
      options = options.dup
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
      # Perform 2-level deep merge on the params, so if the passed params and client params will both have hashes stored on a key they
      # will be merged as well, instead of choosing just one of the values
      params = (params || {}).merge(@client_params) { |key, oldval, newval|
        (oldval.is_a?(Hash) && newval.is_a?(Hash)) ? oldval.merge(newval) : newval
      }
      params[:body] = body if body

      if url.user
        params[:auth] = { 
          :user => CGI.unescape(url.user),
          # We have to unescape the password here since manticore won't do it
          # for us unless its part of the URL
          :password => CGI.unescape(url.password), 
          :eager => true 
        }
      end

      request_uri = format_url(url, path)
      request_uri_as_string = remove_double_escaping(request_uri.to_s)
      begin
        resp = @manticore.send(method.downcase, request_uri_as_string, params)
        # Manticore returns lazy responses by default
        # We want to block for our usage, this will wait for the response to finish
        resp.call
      rescue ::Manticore::ManticoreException => e
        log_request_error(e)
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError.new(e, request_uri_as_string)
      end

      # 404s are excluded because they are valid codes in the case of
      # template installation. We might need a better story around this later
      # but for our current purposes this is correct
      code = resp.code
      if code < 200 || code > 299 && code != 404
        raise ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError.new(code, request_uri, body, resp.body)
      end

      resp
    end

    def log_request_error(e)
      details = { message: e.message, exception: e.class }
      details[:cause] = e.cause if e.respond_to?(:cause)
      details[:backtrace] = e.backtrace if @logger.debug?

      level = case e
      when ::Manticore::Timeout
        :debug
      when ::Manticore::UnknownException
        :warn
      else
        :info
      end

      @logger.send level, "Failed to perform request", details
      log_java_exception(details[:cause], :debug) if details[:cause] && @logger.debug?
    end

    def log_java_exception(e, level = :debug)
      return unless e.is_a?(java.lang.Exception)
      # @logger.name using the same convention as LS does
      logger = self.class.name.gsub('::', '.').downcase
      logger = org.apache.logging.log4j.LogManager.getLogger(logger)
      logger.send(level, '', e) # logger.error('', e) - prints nested causes
    end

    # Returned urls from this method should be checked for double escaping.
    def format_url(url, path_and_query=nil)
      request_uri = url.clone
      
      # We excise auth info from the URL in case manticore itself tries to stick
      # sensitive data in a thrown exception or log data
      request_uri.user = nil
      request_uri.password = nil

      return request_uri.to_s if path_and_query.nil?

      parsed_path_and_query = java.net.URI.new(path_and_query)

      new_query_parts = [request_uri.query, parsed_path_and_query.query].select do |part|
        part && !part.empty? # Skip empty nil and ""
      end
      
      request_uri.query = new_query_parts.join("&") unless new_query_parts.empty?

      # use `raw_path`` as `path` will unescape any escaped '/' in the path
      request_uri.path = "#{request_uri.path}/#{parsed_path_and_query.raw_path}".gsub(/\/{2,}/, "/")
      request_uri
    end

    # Later versions of SafeURI will also escape the '%' sign in an already escaped URI.
    # (If the path variable is used, it constructs a new java.net.URI object using the multi-arg constructor,
    # which will escape any '%' characters in the path, as opposed to the single-arg constructor which requires illegal
    # characters to be already escaped, and will throw otherwise)
    # The URI needs to have been previously escaped, as it does not play nice with an escaped '/' in the
    # middle of a URI, as required by date math, treating it as a path separator
    def remove_double_escaping(url)
      url.gsub(/%25([0-9A-F]{2})/i, '%\1')
    end

    def close
      @manticore.close
    end

  end
end; end; end; end
