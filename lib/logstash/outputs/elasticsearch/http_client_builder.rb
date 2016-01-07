module LogStash; module Outputs; class ElasticSearch;
  module HttpClientBuilder
    def self.build(logger, hosts, params)
      client_settings = {}

      common_options = {
        :client_settings => client_settings,
        :sniffing => params["sniffing"],
        :sniffing_delay => params["sniffing_delay"]
      }

      common_options[:timeout] = params["timeout"] if params["timeout"]
      client_settings[:path] = "/#{params["path"]}/".gsub(/\/+/, "/") # Normalize slashes
      logger.debug? && logger.debug("Normalizing http path", :path => params["path"], :normalized => client_settings[:path])

      client_settings.merge! setup_ssl(logger, params)
      client_settings.merge! setup_proxy(logger, params)
      common_options.merge! setup_basic_auth(logger, params)

      # Update API setup
      raise( Logstash::ConfigurationError,
        "doc_as_upsert and scripted_upsert are mutually exclusive."
      ) if params["doc_as_upsert"] and params["scripted_upsert"]

      raise(
        LogStash::ConfigurationError,
        "Specifying action => 'update' needs a document_id."
      ) if params['action'] == 'update' and params.fetch('document_id', '') == ''

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

    def self.setup_proxy(logger, params)
      proxy = params["proxy"]
      return {} unless proxy

      # Symbolize keys
      proxy = if proxy.is_a?(Hash)
                Hash[proxy.map {|k,v| [k.to_sym, v]}]
              elsif proxy.is_a?(String)
                proxy
              else
                raise LogStash::ConfigurationError, "Expected 'proxy' to be a string or hash, not '#{proxy}''!"
              end

      return {:proxy => proxy}
    end

    def self.setup_ssl(logger, params)
      return {} unless params["ssl"]

      cacert, truststore, truststore_password, keystore, keystore_password =
        params.values_at('cacert', 'truststore', 'truststore_password', 'keystore', 'keystore_password')

      if cacert && truststore
        raise(LogStash::ConfigurationError, "Use either \"cacert\" or \"truststore\" when configuring the CA certificate") if truststore
      end

      ssl_options = {}

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
      return {} unless user && password

      {
        :user => user,
        :password => password.value
      }
    end
  end
end; end; end