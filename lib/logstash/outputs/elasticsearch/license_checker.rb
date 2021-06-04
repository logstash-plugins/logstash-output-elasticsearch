module LogStash; module Outputs; class ElasticSearch
  class LicenseChecker

    def initialize(logger)
      @logger = logger
    end

    # Figure out if the provided license is appropriate or not
    # The appropriate_license? methods is the method called from LogStash::Outputs::ElasticSearch::HttpClient::Pool#healthcheck!
    # @param pool
    # @param url [LogStash::Util::SafeURI] ES node URL
    # @return [Boolean] true if provided license is deemed appropriate
    def appropriate_license?(pool, es_version, url)
      license = extract_license(pool.get_license(url))
      case license_status(license)
      when 'active'
        true
      when nil
        if pool.major_version(es_version) < 7 || 
            (pool.major_version(es_version) == 7 && pool.minor_version(es_version) < 11)
          # last known OSS version 7.10.2
          warn_no_license_deprecation(url)
          true
        else
          warn_no_license(url)
          false
        end
      else # 'invalid', 'expired'
        warn_invalid_license(url, license)
        true
      end
    end

    NO_LICENSE = {}.freeze
    private_constant :NO_LICENSE

    def extract_license(license)
      license.fetch("license", NO_LICENSE)
    end

    def license_status(license)
      license.fetch("status", nil)
    end

    private

    def warn_no_license_deprecation(url)
      @logger.warn("DEPRECATION WARNING: Connecting to an OSS distribution of Elasticsearch using the default distribution of Logstash will stop working in Logstash 8.0.0. Please upgrade to the default distribution of Elasticsearch, or use the OSS distribution of Logstash", :url => url.sanitized.to_s)
    end

    def warn_no_license(url)
      @logger.error("Could not connect to a compatible version of Elasticsearch", url: url.sanitized.to_s)
    end

    def warn_invalid_license(url, license)
      @logger.warn("Elasticsearch license is not active, please check Elasticsearch’s licensing information",
                   url: url.sanitized.to_s, license: license)
    end

  end
end; end; end
