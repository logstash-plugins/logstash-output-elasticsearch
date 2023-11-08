require "concurrent/atomic/atomic_reference"
require "logstash/plugin_mixins/elasticsearch/noop_license_checker"

module LogStash; module Outputs; class ElasticSearch; class HttpClient;
  class Pool
    class NoConnectionAvailableError < Error; end
    class BadResponseCodeError < Error
      attr_reader :url, :response_code, :request_body, :response_body

      def initialize(response_code, url, request_body, response_body)
        super("Got response code '#{response_code}' contacting Elasticsearch at URL '#{url}'")

        @response_code = response_code
        @url = url
        @request_body = request_body
        @response_body = response_body
      end

      def invalid_eav_header?
        @response_code == 400 && @response_body&.include?(ELASTIC_API_VERSION)
      end

      def invalid_credentials?
        @response_code == 401
      end

      def forbidden?
        @response_code == 403
      end

      def too_many_requests?
        @response_code == 429
      end

    end

    class HostUnreachableError < Error;
      attr_reader :original_error, :url

      def initialize(original_error, url)
        super("Elasticsearch Unreachable: [#{url}][#{original_error.class}] #{original_error.message}")

        @original_error = original_error
        @url = url
      end

    end

    attr_reader :logger, :adapter, :sniffing, :sniffer_delay, :resurrect_delay, :healthcheck_path, :sniffing_path, :bulk_path
    attr_reader :license_checker # license_checker is used by the pool specs

    ROOT_URI_PATH = '/'.freeze
    LICENSE_PATH = '/_license'.freeze

    VERSION_6_TO_7 = ::Gem::Requirement.new([">= 6.0.0", "< 7.0.0"])
    VERSION_7_TO_7_14 = ::Gem::Requirement.new([">= 7.0.0", "< 7.14.0"])

    DEFAULT_OPTIONS = {
      :healthcheck_path => ROOT_URI_PATH,
      :sniffing_path => "/_nodes/http",
      :bulk_path => "/_bulk",
      :scheme => 'http',
      :resurrect_delay => 5,
      :sniffing => false,
      :sniffer_delay => 10,
    }.freeze

    BUILD_FLAVOR_SERVERLESS = 'serverless'.freeze
    ELASTIC_API_VERSION = "Elastic-Api-Version".freeze
    DEFAULT_EAV_HEADER = { ELASTIC_API_VERSION => "2023-10-31" }.freeze

    def initialize(logger, adapter, initial_urls=[], options={})
      @logger = logger
      @adapter = adapter
      @metric = options[:metric]
      @initial_urls = initial_urls

      raise ArgumentError, "No URL Normalizer specified!" unless options[:url_normalizer]
      @url_normalizer = options[:url_normalizer]
      DEFAULT_OPTIONS.merge(options).tap do |merged|
        @bulk_path = merged[:bulk_path]
        @sniffing_path = merged[:sniffing_path]
        @healthcheck_path = merged[:healthcheck_path]
        @resurrect_delay = merged[:resurrect_delay]
        @sniffing = merged[:sniffing]
        @sniffer_delay = merged[:sniffer_delay]
      end

      # Used for all concurrent operations in this class
      @state_mutex = Mutex.new

      # Holds metadata about all URLs
      @url_info = {}
      @stopping = false

      @license_checker = options[:license_checker] || LogStash::PluginMixins::ElasticSearch::NoopLicenseChecker::INSTANCE

      @last_es_version = Concurrent::AtomicReference.new
      @build_flavor = Concurrent::AtomicReference.new
    end

    def start
      update_initial_urls
      start_resurrectionist
      start_sniffer if @sniffing
    end

    def update_initial_urls
      update_urls(@initial_urls)
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
      @state_mutex.synchronize { @url_info.values.select {|v| v[:state] == :alive }.count }
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
    ES2_AND_ABOVE_SNIFF_RE_URL  = /([^\/]*)?\/?([^:]*):([0-9]+)/
    # Sniffs and returns the results. Does not update internal URLs!
    def check_sniff
      _, url_meta, resp = perform_request(:get, @sniffing_path)
      @metric.increment(:sniff_requests)
      parsed = LogStash::Json.load(resp.body)
      nodes = parsed['nodes']
      if !nodes || nodes.empty?
        @logger.warn("Sniff returned no nodes! Will not update hosts.")
        return nil
      else
        sniff(nodes)
      end
    end

    def major_version(version_string)
      version_string.split('.').first.to_i
    end

    def sniff(nodes)
      nodes.map do |id,info|
        # Skip master-only nodes
        next if info["roles"] && info["roles"] == ["master"]
        address_str_to_uri(info["http"]["publish_address"]) if info["http"]
      end.compact
    end

    def address_str_to_uri(addr_str)
      matches = addr_str.match(ES1_SNIFF_RE_URL) || addr_str.match(ES2_AND_ABOVE_SNIFF_RE_URL)
      if matches
        host = matches[1].empty? ? matches[2] : matches[1]
        ::LogStash::Util::SafeURI.new("#{host}:#{matches[3]}")
      end
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
          healthcheck!(false)
        end
      end
    end

    # Retrieve ES node license information
    # @param url [LogStash::Util::SafeURI] ES node URL
    # @return [Hash] deserialized license document or empty Hash upon any error
    def get_license(url)
      response = perform_request_to_url(url, :get, LICENSE_PATH)
      LogStash::Json.load(response.body)
    rescue => e
      logger.error("Unable to get license information", url: url.sanitized.to_s, exception: e.class, message: e.message)
      {}
    end

    def health_check_request(url)
      logger.debug("Running health check to see if an Elasticsearch connection is working",
                   :healthcheck_url => url.sanitized.to_s, :path => @healthcheck_path)
      begin
        response = perform_request_to_url(url, :head, @healthcheck_path)
        return response, nil
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        logger.warn("Health check failed", code: e.response_code, url: e.url, message: e.message)
        return nil, e
      end
    end

    def healthcheck!(register_phase = true)
      # Try to keep locking granularity low such that we don't affect IO...
      @state_mutex.synchronize { @url_info.select {|url,meta| meta[:state] != :alive } }.each do |url,meta|
        begin
          _, health_bad_code_err = health_check_request(url)
          root_response, root_bad_code_err = get_root_path(url) if health_bad_code_err.nil? || register_phase

          # when called from resurrectionist skip the product check done during register phase
          if register_phase
            raise LogStash::ConfigurationError,
                  "Could not read Elasticsearch. Please check the credentials" if root_bad_code_err&.invalid_credentials?
            raise LogStash::ConfigurationError,
                  "Could not read Elasticsearch. Please check the privileges" if root_bad_code_err&.forbidden?
            # when customer_headers is invalid
            raise LogStash::ConfigurationError,
                  "The Elastic-Api-Version header is not valid" if root_bad_code_err&.invalid_eav_header?
            # when it is not Elasticserach
            raise LogStash::ConfigurationError,
                  "Could not connect to a compatible version of Elasticsearch" if root_bad_code_err.nil? && !elasticsearch?(root_response)

            test_serverless_connection(url, root_response)
          end

          raise health_bad_code_err if health_bad_code_err
          raise root_bad_code_err if root_bad_code_err

          # If no exception was raised it must have succeeded!
          logger.warn("Restored connection to ES instance", url: url.sanitized.to_s)

          # We check its ES version
          es_version, build_flavor = parse_es_version(root_response)
          logger.warn("Failed to retrieve Elasticsearch build flavor") if build_flavor.nil?
          logger.warn("Failed to retrieve Elasticsearch version data from connected endpoint, connection aborted", :url => url.sanitized.to_s) if es_version.nil?
          next if es_version.nil?

          @state_mutex.synchronize do
            meta[:version] = es_version
            set_last_es_version(es_version, url)
            set_build_flavor(build_flavor)

            alive = @license_checker.appropriate_license?(self, url)
            meta[:state] = alive ? :alive : :dead
          end
        rescue HostUnreachableError, BadResponseCodeError => e
          logger.warn("Attempted to resurrect connection to dead ES instance, but got an error", url: url.sanitized.to_s, exception: e.class, message: e.message)
        end
      end
    end

    def get_root_path(url, params={})
      begin
        resp = perform_request_to_url(url, :get, ROOT_URI_PATH, params)
        return resp, nil
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        logger.warn("Elasticsearch main endpoint returns #{e.response_code}", message: e.message, body: e.response_body)
        return nil, e
      end
    end

    def test_serverless_connection(url, root_response)
      _, build_flavor = parse_es_version(root_response)
      params = { :headers => DEFAULT_EAV_HEADER }
      _, bad_code_err = get_root_path(url, params) if build_flavor == BUILD_FLAVOR_SERVERLESS
      raise LogStash::ConfigurationError, "The Elastic-Api-Version header is not valid" if bad_code_err&.invalid_eav_header?
    end

    def stop_resurrectionist
      @resurrectionist.join if @resurrectionist
    end

    def resurrectionist_alive?
      @resurrectionist ? @resurrectionist.alive? : nil
    end

    def perform_request(method, path, params={}, body=nil)
      with_connection do |url, url_meta|
        resp = perform_request_to_url(url, method, path, params, body)
        [url, url_meta, resp]
      end
    end

    [:get, :put, :post, :delete, :patch, :head].each do |method|
      define_method(method) do |path, params={}, body=nil|
        _, _, response = perform_request(method, path, params, body)
        response
      end
    end

    def perform_request_to_url(url, method, path, params={}, body=nil)
      params[:headers] = DEFAULT_EAV_HEADER.merge(params[:headers] || {}) if serverless?
      @adapter.perform_request(url, method, path, params, body)
    end

    def normalize_url(uri)
      u = @url_normalizer.call(uri)
      if !u.is_a?(::LogStash::Util::SafeURI)
        raise "URL Normalizer returned a '#{u.class}' rather than a SafeURI! This shouldn't happen!"
      end
      u
    end

    def update_urls(new_urls)
      return if new_urls.nil?

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
        logger.info? && logger.info("Elasticsearch pool URLs updated", :changes => state_changes)
      end

      # Run an inline healthcheck anytime URLs are updated
      # This guarantees that during startup / post-startup
      # sniffing we don't have idle periods waiting for the
      # periodic sniffer to allow new hosts to come online
      healthcheck!
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
      yield url, url_meta
    rescue HostUnreachableError => e
      # Mark the connection as dead here since this is likely not transient
      mark_dead(url, e)
      raise e
    rescue BadResponseCodeError => e
      # These aren't discarded from the pool because these are often very transient
      # errors
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
        logger.warn("Marking url as dead. Last error: [#{error.class}] #{error.message}",
                    :url => url, :error_message => error.message, :error_class => error.class.name)
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
        info = @url_info[url]
        info[:in_use] -= 1 if info # Guard against the condition where the connection has already been deleted
      end
    end

    def last_es_version
      @last_es_version.get
    end

    def maximum_seen_major_version
      @state_mutex.synchronize { @maximum_seen_major_version }
    end

    def serverless?
      @build_flavor.get == BUILD_FLAVOR_SERVERLESS
    end

    private

    # @private executing within @state_mutex
    def set_last_es_version(version, url)
      @last_es_version.set(version)

      major = major_version(version)
      if @maximum_seen_major_version.nil?
        @logger.info("Elasticsearch version determined (#{version})", es_version: major)
        set_maximum_seen_major_version(major)
      elsif major > @maximum_seen_major_version
        warn_on_higher_major_version(major, url)
        @maximum_seen_major_version = major
      end
    end

    def set_maximum_seen_major_version(major)
      if major >= 6
        @logger.warn("Detected a 6.x and above cluster: the `type` event field won't be used to determine the document _type", es_version: major)
      end
      @maximum_seen_major_version = major
    end

    def warn_on_higher_major_version(major, url)
      @logger.warn("Detected a node with a higher major version than previously observed, " +
                   "this could be the result of an Elasticsearch cluster upgrade",
                   previous_major: @maximum_seen_major_version, new_major: major, node_url: url.sanitized.to_s)
    end

    def set_build_flavor(flavor)
      @build_flavor.set(flavor)
    end

    def parse_es_version(response)
      return nil, nil unless (200..299).cover?(response&.code)

      response = LogStash::Json.load(response&.body)
      version_info = response.fetch('version', {})
      es_version = version_info.fetch('number', nil)
      build_flavor = version_info.fetch('build_flavor', nil)

      return es_version, build_flavor
    end

    def elasticsearch?(response)
      return false if response.nil?

      version_info = LogStash::Json.load(response.body)
      return false if version_info['version'].nil?

      version = ::Gem::Version.new(version_info["version"]['number'])
      return false if version < ::Gem::Version.new('6.0.0')

      if VERSION_6_TO_7.satisfied_by?(version)
        return valid_tagline?(version_info)
      elsif VERSION_7_TO_7_14.satisfied_by?(version)
        build_flavor = version_info["version"]['build_flavor']
        return false if build_flavor.nil? || build_flavor != 'default' || !valid_tagline?(version_info)
      else
        # case >= 7.14
        lower_headers = response.headers.transform_keys {|key| key.to_s.downcase }
        product_header = lower_headers['x-elastic-product']
        return false if product_header != 'Elasticsearch'
      end
      return true
    rescue => e
      logger.error("Unable to retrieve Elasticsearch version", exception: e.class, message: e.message)
      false
    end

    def valid_tagline?(version_info)
      tagline = version_info['tagline']
      tagline == "You Know, for Search"
    end
  end
end; end; end; end;
