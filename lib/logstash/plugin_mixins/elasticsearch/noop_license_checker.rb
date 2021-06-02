module LogStash; module PluginMixins; module ElasticSearch
  class NoopLicenseChecker
    INSTANCE = self.new

    def appropriate_license?(pool, es_version, url)
      true
    end
  end
end; end; end
