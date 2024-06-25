Gem::Specification.new do |s|
  s.name            = 'logstash-output-elasticsearch'
  s.version         = '11.22.7'
  s.licenses        = ['apache-2.0']
  s.summary         = "Stores logs in Elasticsearch"
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Elastic"]
  s.email           = 'info@elastic.co'
  s.homepage        = "https://www.elastic.co/guide/en/logstash/current/index.html"
  s.require_paths = ["lib"]

  s.platform = RUBY_PLATFORM

  # Files
  s.files = Dir["lib/**/*","spec/**/*","*.gemspec","*.md","CONTRIBUTORS","Gemfile","LICENSE","NOTICE.TXT", "vendor/jar-dependencies/**/*.jar", "vendor/jar-dependencies/**/*.rb", "VERSION", "docs/**/*"]

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  s.add_runtime_dependency "manticore", '>= 0.8.0', '< 1.0.0'
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'logstash-mixin-ecs_compatibility_support', '~>1.0'
  s.add_runtime_dependency 'logstash-mixin-deprecation_logger_support', '~>1.0'
  s.add_runtime_dependency 'logstash-mixin-ca_trusted_fingerprint_support', '~>1.0'
  s.add_runtime_dependency 'logstash-mixin-normalize_config_support', '~>1.0'

  s.add_development_dependency 'logstash-codec-plain'
  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'flores'
  s.add_development_dependency 'cabin', ['~> 0.6']
  s.add_development_dependency 'webrick'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'rspec-collection_matchers'
  # Still used in some specs, we should remove this ASAP
  s.add_development_dependency 'elasticsearch'
end
