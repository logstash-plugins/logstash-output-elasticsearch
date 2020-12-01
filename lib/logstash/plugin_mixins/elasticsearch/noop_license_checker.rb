module LogStash; module PluginMixins; module ElasticSearch
  class NoopLicenseChecker
    INSTANCE = self.new

    def appropriate_license?(pool, url)
      true
    end
  end
end; end; end
