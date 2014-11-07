Gem::Specification.new do |s|

  s.name            = 'logstash-output-elasticsearch'
  s.version         = '0.1.5'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Logstash Output to Elasticsearch"
  s.description     = "Output events to elasticsearch"
  s.authors         = ["Elasticsearch"]
  s.email           = 'richard.pijnenburg@elasticsearch.com'
  s.homepage        = "http://logstash.net/"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Jar dependencies
  s.requirements << "jar 'org.elasticsearch:elasticsearch', '1.4.0'"

  # Gem dependencies
  s.add_runtime_dependency 'elasticsearch', ['>= 1.0.6', '~> 1.0']
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency 'cabin', ['~> 0.6']
  s.add_runtime_dependency 'ftw', ['>= 0.0.40', '~> 0']
  s.add_runtime_dependency 'logstash', '>= 1.4.0', '< 2.0.0'
  s.add_runtime_dependency 'jar-dependencies'

  if RUBY_PLATFORM == 'java'
    s.add_runtime_dependency "manticore", '~> 0.3'
  end
end

