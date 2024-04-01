require 'cgi'
require "base64"

module LogStash; module Outputs; class ElasticSearch;
  module HttpClientBuilder
    def self.build(logger, hosts, params)
      client_settings = {
        :pool_max => params["pool_max"],
        :pool_max_per_route => params["pool_max_per_route"],
        :check_connection_timeout => params["validate_after_inactivity"],
        :compression_level => params["compression_level"],
        :headers => params["custom_headers"] || {}
      }
      
      client_settings[:proxy] = params["proxy"] if params["proxy"]
      
      common_options = {
        :license_checker => params["license_checker"],
        :client_settings => client_settings,
        :metric => params["metric"],
        :resurrect_delay => params["resurrect_delay"]
      }

      if params["sniffing"]
        common_options[:sniffing] = true
        common_options[:sniffer_delay] = params["sniffing_delay"]
      end

      common_options[:timeout] = params["timeout"] if params["timeout"]

      if params["path"]
        client_settings[:path] = dedup_slashes("/#{params["path"]}/")
      end

      common_options[:bulk_path] = if params["bulk_path"]
        resolve_filter_path(dedup_slashes("/#{params["bulk_path"]}"))
      else
        resolve_filter_path(dedup_slashes("/#{params["path"]}/_bulk"))
      end

      common_options[:sniffing_path] = if params["sniffing_path"]
         dedup_slashes("/#{params["sniffing_path"]}")
      else
         dedup_slashes("/#{params["path"]}/_nodes/http")
      end

      common_options[:healthcheck_path] = if params["healthcheck_path"]
         dedup_slashes("/#{params["healthcheck_path"]}")
      else
         dedup_slashes("/#{params["path"]}")
      end

      if params["parameters"]
        client_settings[:parameters] = params["parameters"]
      end

      logger.debug? && logger.debug("Normalizing http path", :path => params["path"], :normalized => client_settings[:path])

      client_settings.merge! setup_ssl(logger, params)
      common_options.merge! setup_basic_auth(logger, params)
      client_settings[:headers].merge! setup_api_key(logger, params)

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

      create_http_client(common_options.merge(:hosts => hosts, :logger => logger))
    end

    def self.create_http_client(options)
      LogStash::Outputs::ElasticSearch::HttpClient.new(options)
    end

    def self.setup_ssl(logger, params)
      params["ssl_enabled"] = true if params["hosts"].any? {|h| h.scheme == "https" }
      return {} if params["ssl_enabled"].nil?

      return {:ssl => {:enabled => false}} if params["ssl_enabled"] == false

      ssl_certificate_authorities, ssl_truststore_path, ssl_certificate, ssl_keystore_path = params.values_at('ssl_certificate_authorities', 'ssl_truststore_path', 'ssl_certificate', 'ssl_keystore_path')

      if ssl_certificate_authorities && ssl_truststore_path
        raise LogStash::ConfigurationError, 'Use either "ssl_certificate_authorities/cacert" or "ssl_truststore_path/truststore" when configuring the CA certificate'
      end

      if ssl_certificate && ssl_keystore_path
        raise LogStash::ConfigurationError, 'Use either "ssl_certificate" or "ssl_keystore_path/keystore" when configuring client certificates'
      end

      ssl_options = {:enabled => true}

      if ssl_certificate_authorities&.any?
        raise LogStash::ConfigurationError, 'Multiple values on "ssl_certificate_authorities" are not supported by this plugin' if ssl_certificate_authorities.size > 1
        ssl_options[:ca_file] = ssl_certificate_authorities.first
      end

      setup_ssl_store(ssl_options, 'truststore', params)
      setup_ssl_store(ssl_options, 'keystore', params)

      ssl_key = params["ssl_key"]
      if ssl_certificate
        raise LogStash::ConfigurationError, 'Using an "ssl_certificate" requires an "ssl_key"' unless ssl_key
        ssl_options[:client_cert] = ssl_certificate
        ssl_options[:client_key] = ssl_key
      elsif !ssl_key.nil?
        raise LogStash::ConfigurationError, 'An "ssl_certificate" is required when using an "ssl_key"'
      end

      ssl_verification_mode = params["ssl_verification_mode"]
      unless ssl_verification_mode.nil?
        case ssl_verification_mode
        when 'none'
          logger.warn "You have enabled encryption but DISABLED certificate verification, " +
                        "to make sure your data is secure set `ssl_verification_mode => full`"
          ssl_options[:verify] = :disable
        else
          # Manticore's :default maps to Apache HTTP Client's DefaultHostnameVerifier,
          # which is the modern STRICT verifier that replaces the deprecated StrictHostnameVerifier
          ssl_options[:verify] = :default
        end
      end

      ssl_options[:cipher_suites] = params["ssl_cipher_suites"] if params.include?("ssl_cipher_suites")
      ssl_options[:trust_strategy] = params["ssl_trust_strategy"] if params.include?("ssl_trust_strategy")

      protocols = params['ssl_supported_protocols']
      ssl_options[:protocols] = protocols if protocols && protocols.any?

      { ssl: ssl_options }
    end

    # @param kind is a string [truststore|keystore]
    def self.setup_ssl_store(ssl_options, kind, params)
      store_path = params["ssl_#{kind}_path"]
      if store_path
        ssl_options[kind.to_sym] = store_path
        ssl_options["#{kind}_type".to_sym] = params["ssl_#{kind}_type"] if params.include?("ssl_#{kind}_type")
        ssl_options["#{kind}_password".to_sym] = params["ssl_#{kind}_password"].value if params.include?("ssl_#{kind}_password")
      end
    end

    def self.setup_basic_auth(logger, params)
      user, password = params["user"], params["password"]
      
      return {} unless user && password && password.value

      {
        :user => CGI.escape(user),
        :password => CGI.escape(password.value)
      }
    end

    def self.setup_api_key(logger, params)
      api_key = params["api_key"]

      return {} unless (api_key && api_key.value)

      { "Authorization" => "ApiKey " + Base64.strict_encode64(api_key.value) }
    end

    private
    def self.dedup_slashes(url)
      url.gsub(/\/+/, "/")
    end

    # Set a `filter_path` query parameter if it is not already set to be
    # `filter_path=errors,items.*.error,items.*.status` to reduce the payload between Logstash and Elasticsearch
    def self.resolve_filter_path(url)
      return url if url.match?(/(?:[&|?])filter_path=/)
      ("#{url}#{query_param_separator(url)}filter_path=errors,items.*.error,items.*.status")
    end

    def self.query_param_separator(url)
      url.match?(/\?[^\s#]+/) ? '&' : '?'
    end
  end
end; end; end
