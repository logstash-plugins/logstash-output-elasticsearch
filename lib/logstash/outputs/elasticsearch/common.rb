require "logstash/outputs/elasticsearch/template_manager"

module LogStash; module Outputs; class ElasticSearch;
  module Common
    attr_reader :client, :hosts

    RETRYABLE_CODES = [429, 503]
    SUCCESS_CODES = [200, 201]
    CONFLICT_CODE = 409

    # When you use external versioning, you are communicating that you want
    # to ignore conflicts. More obviously, since an external version is a 
    # constant part of the incoming document, we should not retry, as retrying
    # will never succeed. 
    VERSION_TYPES_PERMITTING_CONFLICT = ["external", "external_gt", "external_gte"]

    def register
      @stopping = Concurrent::AtomicBoolean.new(false)
      setup_hosts # properly sets @hosts
      build_client
      install_template
      check_action_validity

      @logger.info("New Elasticsearch output", :class => self.class.name, :hosts => @hosts.map(&:sanitized))
    end

    # Receive an array of events and immediately attempt to index them (no buffering)
    def multi_receive(events)
      if @flush_size
        events.each_slice(@flush_size) do |slice|
          retrying_submit(slice.map {|e| event_action_tuple(e) })
        end
      else
        retrying_submit(events.map {|e| event_action_tuple(e)})
      end
    end

    # Convert the event into a 3-tuple of action, params, and event
    def event_action_tuple(event)
      params = event_action_params(event)
      action = event.sprintf(@action)
      [action, params, event]
    end

    def setup_hosts
      @hosts = Array(@hosts)
      if @hosts.empty?
        @logger.info("No 'host' set in elasticsearch output. Defaulting to localhost")
        @hosts.replace(["localhost"])
      end
    end

    def install_template
      TemplateManager.install_template(self)
    end

    def check_action_validity
      raise LogStash::ConfigurationError, "No action specified!" unless @action

      # If we're using string interpolation, we're good!
      return if @action =~ /%{.+}/
      return if valid_actions.include?(@action)

      raise LogStash::ConfigurationError, "Action '#{@action}' is invalid! Pick one of #{valid_actions} or use a sprintf style statement"
    end

    # To be overidden by the -java version
    VALID_HTTP_ACTIONS=["index", "delete", "create", "update"]
    def valid_actions
      VALID_HTTP_ACTIONS
    end

    def retrying_submit(actions)
      # Initially we submit the full list of actions
      submit_actions = actions

      sleep_interval = @retry_initial_interval

      while submit_actions && submit_actions.length > 0

        # We retry with whatever is didn't succeed
        begin
          submit_actions = submit(submit_actions)
          if submit_actions && submit_actions.size > 0
            @logger.error("Retrying individual actions")
            submit_actions.each {|action| @logger.error("Action", action) }
          end
        rescue => e
          @logger.error("Encountered an unexpected error submitting a bulk request! Will retry.",
                       :error_message => e.message,
                       :class => e.class.name,
                       :backtrace => e.backtrace)
        end

        # Everything was a success!
        break if !submit_actions || submit_actions.empty?

        # If we're retrying the action sleep for the recommended interval
        # Double the interval for the next time through to achieve exponential backoff
        Stud.stoppable_sleep(sleep_interval) { @stopping.true? }
        sleep_interval = next_sleep_interval(sleep_interval)
      end
    end

    def sleep_for_interval(sleep_interval)
      Stud.stoppable_sleep(sleep_interval) { @stopping.true? }
      next_sleep_interval(sleep_interval)
    end

    def next_sleep_interval(current_interval)
      doubled = current_interval * 2
      doubled > @retry_max_interval ? @retry_max_interval : doubled
    end

    def submit(actions)
      bulk_response = safe_bulk(actions)

      # If the response is nil that means we were in a retry loop
      # and aborted since we're shutting down
      # If it did return and there are no errors we're good as well
      return if bulk_response.nil? || !bulk_response["errors"]

      actions_to_retry = []
      bulk_response["items"].each_with_index do |response,idx|
        action_type, action_props = response.first

        status = action_props["status"]
        failure  = action_props["error"]
        action = actions[idx]
        action_params = action[1]

        if SUCCESS_CODES.include?(status)
          next
        elsif CONFLICT_CODE == status && VERSION_TYPES_PERMITTING_CONFLICT.include?(action_params[:version_type])
          @logger.debug "Ignoring external version conflict: status[#{status}] failure[#{failure}] version[#{action_params[:version]}] version_type[#{action_params[:version_type]}]"
          next
        elsif RETRYABLE_CODES.include?(status)
          @logger.info "retrying failed action with response code: #{status} (#{failure})"
          actions_to_retry << action
        elsif !failure_type_logging_whitelist.include?(failure["type"])
          @logger.warn "Failed action.", status: status, action: action, response: response
        end
      end

      actions_to_retry
    end

    # get the action parameters for the given event
    def event_action_params(event)
      type = get_event_type(event)

      params = {
        :_id => @document_id ? event.sprintf(@document_id) : nil,
        :_index => event.sprintf(@index),
        :_type => type,
        :_routing => @routing ? event.sprintf(@routing) : nil
      }

      if @pipeline
        params[:pipeline] = event.sprintf(@pipeline)
      end

     if @parent
        params[:parent] = event.sprintf(@parent)
      end

      if @action == 'update'
        params[:_upsert] = LogStash::Json.load(event.sprintf(@upsert)) if @upsert != ""
        params[:_script] = event.sprintf(@script) if @script != ""
        params[:_retry_on_conflict] = @retry_on_conflict
      end

      if @version
        params[:version] = event.sprintf(@version)
      end

      if @version_type
        params[:version_type] = event.sprintf(@version_type)
      end

      params
    end

    # Determine the correct value for the 'type' field for the given event
    def get_event_type(event)
      # Set the 'type' value for the index.
      type = if @document_type
               event.sprintf(@document_type)
             else
               event.get("type") || "logs"
             end

      if !(type.is_a?(String) || type.is_a?(Numeric))
        @logger.warn("Bad event type! Non-string/integer type value set!", :type_class => type.class, :type_value => type.to_s, :event => event)
      end

      type.to_s
    end

    # Rescue retryable errors during bulk submission
    def safe_bulk(actions)
      sleep_interval = @retry_initial_interval
      begin
        es_actions = actions.map {|action_type, params, event| [action_type, params, event.to_hash]}
        response = @client.bulk(es_actions)
        response
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::HostUnreachableError => e
        # If we can't even connect to the server let's just print out the URL (:hosts is actually a URL)
        # and let the user sort it out from there
        @logger.error(
          "Attempted to send a bulk request to elasticsearch'"+
            " but Elasticsearch appears to be unreachable or down!",
          :error_message => e.message,
          :class => e.class.name,
          :will_retry_in_seconds => sleep_interval
        )
        @logger.debug("Failed actions for last bad bulk request!", :actions => actions)

        # We retry until there are no errors! Errors should all go to the retry queue
        sleep_interval = sleep_for_interval(sleep_interval)
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::NoConnectionAvailableError => e
        @logger.error(
          "Attempted to send a bulk request to elasticsearch, but no there are no living connections in the connection pool. Perhaps Elasticsearch is unreachable or down?",
          :error_message => e.message,
          :class => e.class.name,
          :will_retry_in_seconds => sleep_interval
        )
        Stud.stoppable_sleep(sleep_interval) { @stopping.true? }
        sleep_interval = next_sleep_interval(sleep_interval)
        retry unless @stopping.true?
      rescue ::LogStash::Outputs::ElasticSearch::HttpClient::Pool::BadResponseCodeError => e
        if RETRYABLE_CODES.include?(e.response_code)
          log_hash = {:code => e.response_code, :url => e.url.sanitized}
          log_hash[:body] = e.body if @logger.debug? # Generally this is too verbose
          @logger.error("Attempted to send a bulk request to elasticsearch but received a bad HTTP response code!", log_hash)

          sleep_interval = sleep_for_interval(sleep_interval)
          retry unless @stopping.true?
        else
          log_hash = {:code => e.response_code, 
                      :response_body => e.response_body}
          log_hash[:request_body] = e.request_body if @logger.debug?
          @logger.error("Got a bad response code from server, but this code is not considered retryable. Request will be dropped", log_hash)
        end
      rescue => e
        # Stuff that should never happen
        # For all other errors print out full connection issues
        @logger.error(
          "An unknown error occurred sending a bulk request to Elasticsearch. We will retry indefinitely",
          :error_message => e.message,
          :error_class => e.class.name,
          :backtrace => e.backtrace
        )

        @logger.debug("Failed actions for last bad bulk request!", :actions => actions)

        # We retry until there are no errors! Errors should all go to the retry queue
        sleep_interval = sleep_for_interval(sleep_interval)
        retry unless @stopping.true?
      end
    end
  end
end; end; end
