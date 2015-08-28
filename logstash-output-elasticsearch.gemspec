Gem::Specification.new do |s|

  s.name            = 'logstash-output-elasticsearch'
  s.version         = '1.1.0'
  s.licenses        = ['apache-2.0']
  s.summary         = "Logstash Output to Elasticsearch"
  s.description     = "Output events to elasticsearch"
  s.authors         = ["Elastic"]
  s.email           = 'info@elastic.co'
  s.homepage        = "http://logstash.net/"
  s.require_paths = ["lib"]

  # Files
  s.files = Dir.glob(["*.gemspec", "lib/**/*.rb", "spec/**/*.rb", "vendor/*"])

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency 'concurrent-ruby'
  s.add_runtime_dependency 'elasticsearch', ['>= 1.0.10', '~> 1.0']
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency 'cabin', ['~> 0.6']
  s.add_runtime_dependency "logstash-core", '>= 1.4.0', '< 2.0.0'

  s.add_development_dependency 'ftw', '~> 0.0.42'
  s.add_development_dependency 'logstash-input-generator'


  if RUBY_PLATFORM == 'java'
    s.platform = RUBY_PLATFORM
    s.add_runtime_dependency "manticore", '~> 0.4.2'
    s.add_runtime_dependency 'jar-dependencies'
    # jar dependencies
    s.requirements << "jar 'org.elasticsearch:elasticsearch', '1.7.0'"
  end

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency "rspec", "~> 3.1.0" # MIT License
  s.add_development_dependency 'longshoreman'
end
