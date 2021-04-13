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
    def appropriate_license?(pool, url)
      license = pool.get_license(url)
      case license_status(license)
      when 'active'
        true
      when nil
        warn_no_license(url)
        true
      else # 'invalid', 'expired'
        warn_invalid_license(url, license)
        true
      end
    end

    def license_status(license)
      license.fetch("license", {}).fetch("status", nil)
    end

    private

    def warn_no_license(url)
      @logger.warn("DEPRECATION WARNING: Connecting to an OSS distribution of Elasticsearch is no longer supported, " +
                       "please upgrade to the default distribution of Elasticsearch", url: url.sanitized.to_s)
    end

    def warn_invalid_license(url, license)
      @logger.warn("DEPRECATION WARNING: Current Elasticsearch license is not active, " +
                   "please check Elasticsearch's licensing information", url: url.sanitized.to_s, license: license)
    end

  end
end; end; end
