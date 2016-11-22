module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  class Pool
    class NoConnectionAvailableError < Error; end
    class BadResponseCodeError < Error
      attr_reader :url, :response_code, :body

      def initialize(response_code, url, body)
        @response_code = response_code
        @url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
        @body = body
      end

      def message
        "Got response code '#{response_code}' contact Elasticsearch at URL '#{@url}'"
      end
    end
    class HostUnreachableError < Error;
      attr_reader :original_error, :url

      def initialize(original_error, url)
        @original_error = original_error
        @url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
      end

      def message
        "Elasticsearch Unreachable: [#{@url}][#{original_error.class}] #{original_error.message}"
      end
    end

    attr_reader :logger, :adapter, :sniffing, :sniffer_delay, :resurrect_delay, :auth, :healthcheck_path

    DEFAULT_OPTIONS = {
      :healthcheck_path => '/'.freeze,
      :scheme => 'http',
      :resurrect_delay => 5,
      :auth => nil, # Can be set to {:user => 'user', :password => 'pass'}
      :sniffing => false,
      :sniffer_delay => 10,
    }.freeze

    def initialize(logger, adapter, initial_urls=[], options={})
      @logger = logger
      @adapter = adapter

      DEFAULT_OPTIONS.merge(options).tap do |merged|
        @healthcheck_path = merged[:healthcheck_path]
        @scheme = merged[:scheme]
        @resurrect_delay = merged[:resurrect_delay]
        @auth = merged[:auth]
        @sniffing = merged[:sniffing]
        @sniffer_delay = merged[:sniffer_delay]
      end

      # Override the scheme if one is explicitly set in urls
      if initial_urls.any? {|u| u.scheme == 'https'} && @scheme == 'http'
        raise ArgumentError, "HTTP was set as scheme, but an HTTPS URL was passed in!"
      end

      # Used for all concurrent operations in this class
      @state_mutex = Mutex.new

      # Holds metadata about all URLs
      @url_info = {}
      @stopping = false
      
      update_urls(initial_urls)
      
      start_resurrectionist
      start_sniffer if @sniffing
    end

    def close
      @state_mutex.synchronize { @stopping = true }

      logger.debug  "Stopping sniffer"
      stop_sniffer

      logger.debug  "Stopping resurrectionist"
      stop_resurrectionist

      logger.debug  "Waiting for in use manticore connections"
      wait_for_in_use_connections

      logger.debug("Closing adapter #{@adapter}")
      @adapter.close
    end

    def wait_for_in_use_connections
      until in_use_connections.empty?
        logger.info "Blocked on shutdown to in use connections #{@state_mutex.synchronize {@url_info}}"
        sleep 1
      end
    end

    def in_use_connections
      @state_mutex.synchronize { @url_info.values.select {|v| v[:in_use] > 0 } }
    end

    def alive_urls_count
      @state_mutex.synchronize { @url_info.values.select {|v| !v[:state] == :alive }.count }
    end

    def url_info
      @state_mutex.synchronize { @url_info }
    end

    def urls
      url_info.keys
    end

    def until_stopped(task_name, delay)
      last_done = Time.now
      until @state_mutex.synchronize { @stopping }
        begin
          now = Time.now
          if (now - last_done) >= delay
            last_done = now
            yield
          end
          sleep 1
        rescue => e
          logger.warn(
            "Error while performing #{task_name}",
            :error_message => e.message,
            :class => e.class.name,
            :backtrace => e.backtrace
            )
        end
      end
    end

    def start_sniffer
      @sniffer = Thread.new do
        until_stopped("sniffing", sniffer_delay) do
          begin
            sniff!
          rescue NoConnectionAvailableError => e
            @state_mutex.synchronize { # Synchronize around @url_info
              logger.warn("Elasticsearch output attempted to sniff for new connections but cannot. No living connections are detected. Pool contains the following current URLs", :url_info => @url_info) }
          end
        end
      end
    end

    # Sniffs the cluster then updates the internal URLs
    def sniff!
      update_urls(check_sniff)
    end

    ES1_SNIFF_RE_URL  = /\[([^\/]*)?\/?([^:]*):([0-9]+)\]/
    ES2_SNIFF_RE_URL  = /([^\/]*)?\/?([^:]*):([0-9]+)/
    # Sniffs and returns the results. Does not update internal URLs!
    def check_sniff
      url, resp = perform_request(:get, '_nodes')
      parsed = LogStash::Json.load(resp.body)
      parsed['nodes'].map do |id,info|
        # TODO Make sure this works with shield. Does that listed
        # stuff as 'https_address?'
        addr_str = info['http_address'].to_s
        next unless addr_str # Skip hosts with HTTP disabled


        # Only connect to nodes that serve data
        # this will skip connecting to client, tribe, and master only nodes
        # Note that if 'attributes' is NOT set, then that's just a regular node
        # with master + data + client enabled, so we allow that
        attributes = info['attributes']
        next if attributes && attributes['data'] == 'false'

        matches = addr_str.match(ES1_SNIFF_RE_URL) || addr_str.match(ES2_SNIFF_RE_URL)
        if matches
          host = matches[1].empty? ? matches[2] : matches[1]
          port = matches[3]
          URI.parse("#{@scheme}://#{host}:#{port}")
        end
      end.compact
    end

    def stop_sniffer
      @sniffer.join if @sniffer
    end

    def sniffer_alive?
      @sniffer ? @sniffer.alive? : nil
    end

    def start_resurrectionist
      @resurrectionist = Thread.new do
        until_stopped("resurrection", @resurrect_delay) do
          healthcheck!
        end
      end
    end

    def healthcheck!
      # Try to keep locking granularity low such that we don't affect IO...
      @state_mutex.synchronize { @url_info.select {|url,meta| meta[:state] != :alive } }.each do |url,meta|
        safe_url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
        begin
          logger.info("Running health check to see if an Elasticsearch connection is working",
                      url: safe_url, healthcheck_path: @healthcheck_path)
          response = perform_request_to_url(url, "HEAD", @healthcheck_path)
          # If no exception was raised it must have succeeded!
          logger.warn("Restored connection to ES instance", :url => safe_url)
          @state_mutex.synchronize { meta[:state] = :alive }
        rescue HostUnreachableError, BadResponseCodeError => e
          logger.warn("Attempted to resurrect connection to dead ES instance, but got an error.", url: safe_url, error_type: e.class, error: e.message)
        end
      end
    end

    def stop_resurrectionist
      @resurrectionist.join
    end

    def resurrectionist_alive?
      @resurrectionist.alive?
    end

    def perform_request(method, path, params={}, body=nil)
      with_connection do |url|
        resp = perform_request_to_url(url, method, path, params, body)
        [url, resp]
      end
    end

    [:get, :put, :post, :delete, :patch, :head].each do |method|
      define_method(method) do |path, params={}, body=nil|
        perform_request(method, path, params, body)
      end
    end

    def perform_request_to_url(url, method, path, params={}, body=nil)
      res = @adapter.perform_request(url, method, path, params, body)
    rescue *@adapter.host_unreachable_exceptions => e
      raise HostUnreachableError.new(e, url), "Could not reach host #{e.class}: #{e.message}"
    end

    def normalize_url(uri)
      raise ArgumentError, "Only URI objects may be passed in!" unless uri.is_a?(URI)
      uri = uri.clone

      # Set credentials if need be
      if @auth && !uri.user
        uri.user ||= @auth[:user]
        uri.password ||= @auth[:password]
      end

      uri.scheme = @scheme

      uri
    end

    def update_urls(new_urls)
      # Normalize URLs
      new_urls = new_urls.map(&method(:normalize_url))

      # Used for logging nicely
      state_changes = {:removed => [], :added => []}
      @state_mutex.synchronize do
        # Add new connections
        new_urls.each do |url|
          # URI objects don't have real hash equality! So, since this isn't perf sensitive we do a linear scan
          unless @url_info.keys.include?(url)
            state_changes[:added] << url
            add_url(url)
          end
        end

        # Delete connections not in the new list
        @url_info.each do |url,_|
          unless new_urls.include?(url)
            state_changes[:removed] << url
            remove_url(url)
          end
        end
      end

      if state_changes[:removed].size > 0 || state_changes[:added].size > 0
        if logger.info?
          logger.info("Elasticsearch pool URLs updated", :changes => safe_state_changes(state_changes))
        end
      end
      
      # Run an inline healthcheck anytime URLs are updated
      # This guarantees that during startup / post-startup
      # sniffing we don't have idle periods waiting for the
      # periodic sniffer to allow new hosts to come online
      healthcheck! 
    end
    
    def safe_state_changes(state_changes)
      state_changes.reduce({}) do |acc, kv|
        k,v = kv
        acc[k] = v.map(&LogStash::Outputs::ElasticSearch::SafeURL.method(:without_credentials)).map(&:to_s)
        acc
      end
    end

    def size
      @state_mutex.synchronize { @url_info.size }
    end

    def add_url(url)
      @url_info[url] ||= empty_url_meta
    end

    def remove_url(url)
      @url_info.delete(url)
    end

    def empty_url_meta
      {
        :in_use => 0,
        :state => :unknown
      }
    end

    def with_connection
      url, url_meta = get_connection

      # Custom error class used here so that users may retry attempts if they receive this error
      # should they choose to
      raise NoConnectionAvailableError, "No Available connections" unless url
      yield url
    rescue HostUnreachableError => e
      # Mark the connection as dead here since this is likely not transient
      mark_dead(url, e)
      raise e
    rescue BadResponseCodeError => e
      # These aren't discarded from the pool because these are often very transient
      # errors
      raise e
    rescue => e
      logger.warn("UNEXPECTED POOL ERROR", :e => e)
      raise e
    ensure
      return_connection(url)
    end

    def mark_dead(url, error)
      @state_mutex.synchronize do
        meta = @url_info[url]
        # In case a sniff happened removing the metadata just before there's nothing to mark
        # This is an extreme edge case, but it can happen!
        return unless meta 
        safe_url = ::LogStash::Outputs::ElasticSearch::SafeURL.without_credentials(url)
        logger.warn("Marking url as dead.", :reason => error.message, :url => safe_url,
                    :error_message => error.message, :error_class => error.class.name)
        meta[:state] = :dead
        meta[:last_error] = error
        meta[:last_errored_at] = Time.now
      end
    end

    def url_meta(url)
      @state_mutex.synchronize do
        @url_info[url]
      end
    end

    def get_connection
      @state_mutex.synchronize do
        # The goal here is to pick a random connection from the least-in-use connections
        # We want some randomness so that we don't hit the same node over and over, but
        # we also want more 'fair' behavior in the event of high concurrency
        eligible_set = nil
        lowest_value_seen = nil
        @url_info.each do |url,meta|
          meta_in_use = meta[:in_use]
          next if meta[:state] == :dead

          if lowest_value_seen.nil? || meta_in_use < lowest_value_seen
            lowest_value_seen = meta_in_use
            eligible_set = [[url, meta]]
          elsif lowest_value_seen == meta_in_use
            eligible_set << [url, meta]
          end
        end

        return nil if eligible_set.nil?

        pick, pick_meta = eligible_set.sample
        pick_meta[:in_use] += 1

        [pick, pick_meta]
      end
    end

    def return_connection(url)
      @state_mutex.synchronize do
        if @url_info[url] # Guard against the condition where the connection has already been deleted
          @url_info[url][:in_use] -= 1
        end
      end
    end
  end
end; end; end; end;
