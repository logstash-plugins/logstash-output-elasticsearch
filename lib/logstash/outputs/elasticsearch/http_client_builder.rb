require 'cgi'

module LogStash; module Outputs; class ElasticSearch;
  module HttpClientBuilder
    def self.build(logger, hosts, params)
      client_settings = {
        :pool_max => params["pool_max"],
        :pool_max_per_route => params["pool_max_per_route"],
        :check_connection_timeout => params["validate_after_inactivity"]
      }
      
      client_settings[:proxy] = params["proxy"] if params["proxy"]
      
      common_options = {
        :client_settings => client_settings,
        :resurrect_delay => params["resurrect_delay"],
        :healthcheck_path => params["healthcheck_path"],
        :absolute_healthcheck_path => params["absolute_healthcheck_path"],
        :sniffing_path => params["sniffing_path"],
        :absolute_sniffing_path => params["absolute_sniffing_path"]
      }

      if params["sniffing"]
        common_options[:sniffing] = true
        common_options[:sniffer_delay] = params["sniffing_delay"]
      end

      common_options[:timeout] = params["timeout"] if params["timeout"]

      if params["path"]
        client_settings[:path] = "/#{params["path"]}/".gsub(/\/+/, "/") # Normalize slashes
      end

      if params["parameters"]
        client_settings[:parameters] = params["parameters"]
      end

      logger.debug? && logger.debug("Normalizing http path", :path => params["path"], :normalized => client_settings[:path])

      client_settings.merge! setup_ssl(logger, params)
      common_options.merge! setup_basic_auth(logger, params)

      external_version_types = ["external", "external_gt", "external_gte"]
      # External Version validation
      raise(
        LogStash::ConfigurationError,
        "External versioning requires the presence of a version number."
      ) if external_version_types.include?(params.fetch('version_type', '')) and params.fetch("version", nil) == nil
 

      # Create API setup
      raise(
        LogStash::ConfigurationError,
        "External versioning is not supported by the create action."
      ) if params['action'] == 'create' and external_version_types.include?(params.fetch('version_type', ''))

      # Update API setup
      raise( LogStash::ConfigurationError,
        "doc_as_upsert and scripted_upsert are mutually exclusive."
      ) if params["doc_as_upsert"] and params["scripted_upsert"]

      raise(
        LogStash::ConfigurationError,
        "Specifying action => 'update' needs a document_id."
      ) if params['action'] == 'update' and params.fetch('document_id', '') == ''

      raise(
        LogStash::ConfigurationError,
        "External versioning is not supported by the update action. See https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-update.html."
      ) if params['action'] == 'update' and external_version_types.include?(params.fetch('version_type', ''))

      # Update API setup
      update_options = {
        :doc_as_upsert => params["doc_as_upsert"],
        :script_var_name => params["script_var_name"],
        :script_type => params["script_type"],
        :script_lang => params["script_lang"],
        :scripted_upsert => params["scripted_upsert"]
      }
      common_options.merge! update_options if params["action"] == 'update'

      LogStash::Outputs::ElasticSearch::HttpClient.new(
        common_options.merge(:hosts => hosts, :logger => logger)
      )
    end

    def self.setup_ssl(logger, params)
      params["ssl"] = true if params["hosts"].any? {|h| h.scheme == "https" }
      return {} if params["ssl"].nil?

      return {:ssl => {:enabled => false}} if params["ssl"] == false

      cacert, truststore, truststore_password, keystore, keystore_password =
        params.values_at('cacert', 'truststore', 'truststore_password', 'keystore', 'keystore_password')

      if cacert && truststore
        raise(LogStash::ConfigurationError, "Use either \"cacert\" or \"truststore\" when configuring the CA certificate") if truststore
      end

      ssl_options = {:enabled => true}

      if cacert
        ssl_options[:ca_file] = cacert
      elsif truststore
        ssl_options[:truststore_password] = truststore_password.value if truststore_password
      end

      ssl_options[:truststore] = truststore if truststore
      if keystore
        ssl_options[:keystore] = keystore
        ssl_options[:keystore_password] = keystore_password.value if keystore_password
      end
      if !params["ssl_certificate_verification"]
        logger.warn [
                       "** WARNING ** Detected UNSAFE options in elasticsearch output configuration!",
                       "** WARNING ** You have enabled encryption but DISABLED certificate verification.",
                       "** WARNING ** To make sure your data is secure change :ssl_certificate_verification to true"
                     ].join("\n")
        ssl_options[:verify] = false
      end
      { ssl: ssl_options }
    end

    def self.setup_basic_auth(logger, params)
      user, password = params["user"], params["password"]
      unsafe_password = password && password.value
      unsafe_escaped_password = unsafe_password ? CGI.escape(unsafe_password) : nil
      
      return {} unless user && unsafe_escaped_password

      {
        :user => user,
        :password => unsafe_escaped_password
      }
    end
  end
end; end; end
