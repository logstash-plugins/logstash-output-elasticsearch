require "logstash/outputs/elasticsearch/template_manager"

module LogStash; module PluginMixins; module ElasticSearch
  module Common

    # This module defines common methods that can be reused by alternate elasticsearch output plugins such as the elasticsearch_data_streams output.

    attr_reader :hosts

    # These codes apply to documents, not at the request level
    DOC_DLQ_CODES = [400, 404]
    DOC_SUCCESS_CODES = [200, 201]
    DOC_CONFLICT_CODE = 409

    # Perform some ES options validations and Build the HttpClient.
    # Note that this methods may sets the @user, @password, @hosts and @client ivars as a side effect.
    # @param license_checker [#appropriate_license?] An optional license checker that will be used by the Pool class.
    # @return [HttpClient] the new http client
    def build_client(license_checker = nil)
      params["license_checker"] = license_checker

      # the following 3 options validation & setup methods are called inside build_client
      # because they must be executed prior to building the client and logstash
      # monitoring and management rely on directly calling build_client
      # see https://github.com/logstash-plugins/logstash-output-elasticsearch/pull/934#pullrequestreview-396203307
      fill_hosts_from_cloud_id
      validate_authentication

      setup_hosts

      params['ssl_enabled'] = effectively_ssl? unless params.include?('ssl_enabled')

      # inject the TrustStrategy from CATrustedFingerprintSupport
      if trust_strategy_for_ca_trusted_fingerprint
        params["ssl_trust_strategy"] = trust_strategy_for_ca_trusted_fingerprint
      end

      params["metric"] = metric
      if @proxy.eql?('')
        @logger.warn "Supplied proxy setting (proxy => '') has no effect"
      end
      ::LogStash::Outputs::ElasticSearch::HttpClientBuilder.build(@logger, @hosts, params)
    end

    def validate_authentication
      authn_options = 0
      authn_options += 1 if @cloud_auth
      authn_options += 1 if (@api_key && @api_key.value)
      authn_options += 1 if (@user || (@password && @password.value))

      if authn_options > 1
        raise LogStash::ConfigurationError, 'Multiple authentication options are specified, please only use one of user/password, cloud_auth or api_key'
      end

      if @api_key && @api_key.value && !effectively_ssl?
        raise(LogStash::ConfigurationError, "Using api_key authentication requires SSL/TLS secured communication using the `ssl => true` option")
      end

      if @cloud_auth
        @user, @password = parse_user_password_from_cloud_auth(@cloud_auth)
        # params is the plugin global params hash which will be passed to HttpClientBuilder.build
        params['user'], params['password'] = @user, @password
      end
    end
    private :validate_authentication

    def setup_hosts
      @hosts = Array(@hosts)
      if @hosts.empty?
        @logger.info("No 'host' set in elasticsearch output. Defaulting to localhost")
        @hosts.replace(["localhost"])
      end
    end

    def effectively_ssl?
      return @ssl_enabled unless @ssl_enabled.nil?

      hosts = Array(@hosts)
      return false if hosts.nil? || hosts.empty?

      hosts.all? { |host| host && host.scheme == "https" }
    end

    def hosts_default?(hosts)
      # NOTE: would be nice if pipeline allowed us a clean way to detect a config default :
      hosts.is_a?(Array) && hosts.size == 1 && hosts.first.equal?(LogStash::PluginMixins::ElasticSearch::APIConfigs::DEFAULT_HOST)
    end
    private :hosts_default?

    def fill_hosts_from_cloud_id
      return unless @cloud_id

      if @hosts && !hosts_default?(@hosts)
        raise LogStash::ConfigurationError, 'Both cloud_id and hosts specified, please only use one of those.'
      end
      @hosts = parse_host_uri_from_cloud_id(@cloud_id)
    end

    def parse_host_uri_from_cloud_id(cloud_id)
      begin # might not be available on older LS
        require 'logstash/util/cloud_setting_id'
      rescue LoadError
        raise LogStash::ConfigurationError, 'The cloud_id setting is not supported by your version of Logstash, ' +
            'please upgrade your installation (or set hosts instead).'
      end

      begin
        cloud_id = LogStash::Util::CloudSettingId.new(cloud_id) # already does append ':{port}' to host
      rescue ArgumentError => e
        raise LogStash::ConfigurationError, e.message.to_s.sub(/Cloud Id/i, 'cloud_id')
      end
      cloud_uri = "#{cloud_id.elasticsearch_scheme}://#{cloud_id.elasticsearch_host}"
      LogStash::Util::SafeURI.new(cloud_uri)
    end
    private :parse_host_uri_from_cloud_id

    def parse_user_password_from_cloud_auth(cloud_auth)
      begin # might not be available on older LS
        require 'logstash/util/cloud_setting_auth'
      rescue LoadError
        raise LogStash::ConfigurationError, 'The cloud_auth setting is not supported by your version of Logstash, ' +
            'please upgrade your installation (or set user/password instead).'
      end

      cloud_auth = cloud_auth.value if cloud_auth.is_a?(LogStash::Util::Password)
      begin
        cloud_auth = LogStash::Util::CloudSettingAuth.new(cloud_auth)
      rescue ArgumentError => e
        raise LogStash::ConfigurationError, e.message.to_s.sub(/Cloud Auth/i, 'cloud_auth')
      end
      [ cloud_auth.username, cloud_auth.password ]
    end
    private :parse_user_password_from_cloud_auth

    # Plugin initialization extension point (after a successful ES connection).
    def finish_register
    end
    protected :finish_register

    def last_es_version
      client.last_es_version
    end

    def maximum_seen_major_version
      client.maximum_seen_major_version
    end

    def serverless?
      client.serverless?
    end

    def alive_urls_count
      client.alive_urls_count
    end

    def successful_connection?
      !!maximum_seen_major_version && alive_urls_count > 0
    end

    # launch a thread that waits for an initial successful connection to the ES cluster to call the given block
    # @param block [Proc] the block to execute upon initial successful connection
    # @return [Thread] the successful connection wait thread
    def after_successful_connection(&block)
      Thread.new do
        sleep_interval = @retry_initial_interval
        # in case of a pipeline's shutdown_requested?, the method #close shutdown also this thread
        # so no need to explicitly handle it here and return an AbortedBatchException.
        until successful_connection? || @stopping.true?
          @logger.debug("Waiting for connectivity to Elasticsearch cluster, retrying in #{sleep_interval}s")
          sleep_interval = sleep_for_interval(sleep_interval)
        end
        block.call if successful_connection?
      end
    end
    private :after_successful_connection

    def discover_cluster_uuid
      return unless defined?(plugin_metadata)
      cluster_info = client.get('/')
      plugin_metadata.set(:cluster_uuid, cluster_info['cluster_uuid'])
    rescue => e
      details = { message: e.message, exception: e.class, backtrace: e.backtrace }
      details[:body] = e.response_body if e.respond_to?(:response_body)
      @logger.error("Unable to retrieve Elasticsearch cluster uuid", details)
    end

    def retrying_submit(actions)
      # Initially we submit the full list of actions
      submit_actions = actions

      sleep_interval = @retry_initial_interval

      while submit_actions && submit_actions.size > 0

        # We retry with whatever is didn't succeed
        begin
          submit_actions = submit(submit_actions)
          if submit_actions && submit_actions.size > 0
            @logger.info("Retrying individual bulk actions that failed or were rejected by the previous bulk request", count: submit_actions.size)
          end
        rescue => e
          if abort_batch_present? && e.instance_of?(org.logstash.execution.AbortedBatchException)
            # if Logstash support abort of a batch and the batch is aborting,
            # bubble up the exception so that the pipeline can handle it
            raise e
          else
            @logger.error("Encountered an unexpected error submitting a bulk request, will retry",
                          message: e.message, exception: e.class, backtrace: e.backtrace)
          end
        end

        # Everything was a success!
        break if !submit_actions || submit_actions.empty?

        # If we're retrying the action sleep for the recommended interval
        # Double the interval for the next time through to achieve exponential backoff
        sleep_interval = sleep_for_interval(sleep_interval)
      end
    end

    def sleep_for_interval(sleep_interval)
      stoppable_sleep(sleep_interval)
      next_sleep_interval(sleep_interval)
    end

    def stoppable_sleep(interval)
      Stud.stoppable_sleep(interval) { @stopping.true? }
    end

    def next_sleep_interval(current_interval)
      doubled = current_interval * 2
      doubled > @retry_max_interval ? @retry_max_interval : doubled
    end

    def handle_dlq_response(message, action, status, response)
      event, action_params = action.event, [action[0], action[1], action[2]]

      if @dlq_writer
        # TODO: Change this to send a map with { :status => status, :action => action } in the future
        detailed_message = "#{message} status: #{status}, action: #{action_params}, response: #{response}"
        @dlq_writer.write(event, "#{detailed_message}")
      else
        log_level = dig_value(response, 'index', 'error', 'type') == 'invalid_index_name_exception' ? :error : :warn

        @logger.public_send(log_level, message, status: status, action: action_params, response: response)
      end
    end

    private

    def submit(actions)
      bulk_response = safe_bulk(actions)

      # If the response is nil that means we were in a retry loop
      # and aborted since we're shutting down
      return if bulk_response.nil?

      # If it did return and there are no errors we're good as well
      if bulk_response["errors"]
        @bulk_request_metrics.increment(:with_errors)
      else
        @bulk_request_metrics.increment(:successes)
        @document_level_metrics.increment(:successes, actions.size)
        return
      end

      responses = bulk_response["items"]
      if responses.size != actions.size # can not map action -> response reliably
        # an ES bug (on 7.10.2, 7.11.1) where a _bulk request to index X documents would return Y (> X) items
        msg = "Sent #{actions.size} documents but Elasticsearch returned #{responses.size} responses"
        @logger.warn(msg, actions: actions, responses: responses)
        fail("#{msg} (likely a bug with _bulk endpoint)")
      end

      actions_to_retry = []
      responses.each_with_index do |response,idx|
        action_type, action_props = response.first

        status = action_props["status"]
        error  = action_props["error"]
        action = actions[idx]

        # Retry logic: If it is success, we move on. If it is a failure, we have 3 paths:
        # - For 409, we log and drop. there is nothing we can do
        # - For a mapping error, we send to dead letter queue for a human to intervene at a later point.
        # - For everything else there's mastercard. Yep, and we retry indefinitely. This should fix #572 and other transient network issues
        if DOC_SUCCESS_CODES.include?(status)
          @document_level_metrics.increment(:successes)
          next
        elsif DOC_CONFLICT_CODE == status
          @document_level_metrics.increment(:non_retryable_failures)
          @logger.warn "Failed action", status: status, action: action, response: response if log_failure_type?(error)
          next
        elsif @dlq_codes.include?(status)
          handle_dlq_response("Could not index event to Elasticsearch.", action, status, response)
          @document_level_metrics.increment(:dlq_routed)
          next
        else
          # only log what the user whitelisted
          @document_level_metrics.increment(:retryable_failures)
          @logger.info "Retrying failed action", status: status, action: action, error: error if log_failure_type?(error)
          actions_to_retry << action
        end
      end

      actions_to_retry
    end

    def log_failure_type?(failure)
      !silence_errors_in_log.include?(failure["type"])
    end

    # Rescue retryable errors during bulk submission
    # @param actions a [action, params, event.to_hash] tuple
    # @return response [Hash] which contains 'errors' and processed 'items' entries
    def safe_bulk(actions)
      sleep_interval = @retry_initial_interval
      begin
        @client.bulk(actions) # returns { 'errors': ..., 'items': ... }
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError => e
        # If we can't even connect to the server let's just print out the URL (:hosts is actually a URL)
        # and let the user sort it out from there
        @logger.error(
          "Attempted to send a bulk request but Elasticsearch appears to be unreachable or down",
          message: e.message, exception: e.class, will_retry_in_seconds: sleep_interval
        )
        @logger.debug? && @logger.debug("Failed actions for last bad bulk request", :actions => actions)

        # We retry until there are no errors! Errors should all go to the retry queue
        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::NoConnectionAvailableError => e
        @logger.error(
          "Attempted to send a bulk request but there are no living connections in the pool " +
          "(perhaps Elasticsearch is unreachable or down?)",
          message: e.message, exception: e.class, will_retry_in_seconds: sleep_interval
        )

        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        if pipeline_shutdown_requested?
          # when any connection is available and a shutdown is requested
          # the batch can be aborted, eventually for future retry.
          abort_batch_if_available!
        end
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        @bulk_request_metrics.increment(:failures)
        log_hash = {:code => e.response_code, :url => e.url.sanitized.to_s,
                    :content_length => e.request_body.bytesize, :body => e.response_body}
        message = "Encountered a retryable error (will retry with exponential backoff)"

        # We treat 429s as a special case because these really aren't errors, but
        # rather just ES telling us to back off a bit, which we do.
        # The other retryable code is 503, which are true errors
        # Even though we retry the user should be made aware of these
        if e.response_code == 429
          logger.debug(message, log_hash)
        else
          logger.error(message, log_hash)
        end

        sleep_interval = sleep_for_interval(sleep_interval)
        if pipeline_shutdown_requested?
          # In case ES side changes access credentials and a pipeline reload is triggered
          # this error becomes a retry on restart
          abort_batch_if_available!
        end
        retry
      rescue => e # Stuff that should never happen - print out full connection issues
        @logger.error(
          "An unknown error occurred sending a bulk request to Elasticsearch (will retry indefinitely)",
          message: e.message, exception: e.class, backtrace: e.backtrace
        )
        @logger.debug? && @logger.debug("Failed actions for last bad bulk request", :actions => actions)

        sleep_interval = sleep_for_interval(sleep_interval)
        @bulk_request_metrics.increment(:failures)
        retry unless @stopping.true?
      end
    end

    def pipeline_shutdown_requested?
      return super if defined?(super) # since LS 8.1.0
      execution_context&.pipeline&.shutdown_requested?
    end

    def abort_batch_if_available!
      raise org.logstash.execution.AbortedBatchException.new if abort_batch_present?
    end

    def abort_batch_present?
      ::Gem::Version.create(LOGSTASH_VERSION) >= ::Gem::Version.create('8.8.0')
    end

    def dlq_enabled?
      # TODO there should be a better way to query if DLQ is enabled
      # See more in: https://github.com/elastic/logstash/issues/8064
      respond_to?(:execution_context) && execution_context.respond_to?(:dlq_writer) &&
        !execution_context.dlq_writer.inner_writer.is_a?(::LogStash::Util::DummyDeadLetterQueueWriter)
    end

    def dig_value(val, first_key, *rest_keys)
      fail(TypeError, "cannot dig value from #{val.class}") unless val.kind_of?(Hash)
      val = val[first_key]
      return val if rest_keys.empty? || val == nil
      dig_value(val, *rest_keys)
    end

    def register_termination_error?(e)
      e.is_a?(LogStash::ConfigurationError) || e.is_a?(LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError)
    end

    def too_many_requests?(e)
      e.is_a?(LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError) &&
        e.too_many_requests?
    end
  end
end; end; end
