module LogStash; module Outputs; class ElasticSearch
  class LicenseChecker

    def initialize(logger)
      @logger = logger
    end

    # Figure out if the provided license is appropriate or not
    # The appropriate_license? methods is the method called from LogStash::Outputs::ElasticSearch::HttpClient::Pool#healthcheck!
    # @param url [LogStash::Util::SafeURI] ES node URL
    # @param license [Hash] ES node deserialized licence document
    # @return [Boolean] true if provided license is deemed appropriate
    def appropriate_license?(pool, url)
      license = pool.get_license(url)
      if valid_es_license?(license)
        true
      else
        # As this version is to be shipped with Logstash 7.x we won't mark the connection as unlicensed
        #
        #  @logger.error("Cannot connect to the Elasticsearch cluster configured in the Elasticsearch output. Logstash requires the default distribution of Elasticsearch. Please update to the default distribution of Elasticsearch for full access to all free features, or switch to the OSS distribution of Logstash.", :url => url.sanitized.to_s)
        #  meta[:state] = :unlicensed
        #
        # Instead we'll log a deprecation warning and mark it as alive:
        #
        log_license_deprecation_warn(url)
        true
      end
    end

    # Note that valid_es_license? could be private but is used by the Pool specs
    def valid_es_license?(license)
      license.fetch("license", {}).fetch("status", nil) == "active"
    end

    # Note that log_license_deprecation_warn could be private but is used by the Pool specs
    def log_license_deprecation_warn(url)
      @logger.warn("DEPRECATION WARNING: Connecting to an OSS distribution of Elasticsearch using the default distribution of Logstash will stop working in Logstash 8.0.0. Please upgrade to the default distribution of Elasticsearch, or use the OSS distribution of Logstash", :url => url.sanitized.to_s)
    end
  end
end; end; end
