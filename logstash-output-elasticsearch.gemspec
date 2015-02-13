Gem::Specification.new do |s|

  s.name            = 'logstash-output-elasticsearch'
  s.version         = '0.1.15'
  s.licenses        = ['apache-2.0']
  s.summary         = "Logstash Output to Elasticsearch"
  s.description     = "Output events to elasticsearch"
  s.authors         = ["Elasticsearch"]
  s.email           = 'info@elasticsearch.com'
  s.homepage        = "http://logstash.net/"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Jar dependencies
  s.requirements << "jar 'org.elasticsearch:elasticsearch', '1.4.3'"

  # Gem dependencies
  s.add_runtime_dependency 'concurrent-ruby'
  s.add_runtime_dependency 'elasticsearch', ['>= 1.0.6', '~> 1.0']
  s.add_runtime_dependency 'stud', ['>= 0.0.17', '~> 0.0']
  s.add_runtime_dependency 'cabin', ['~> 0.6']
  s.add_runtime_dependency 'logstash', '>= 1.4.0', '< 2.0.0'

  s.add_development_dependency 'ftw', '~> 0.0.42'
  s.add_development_dependency 'logstash-input-generator'


  if RUBY_PLATFORM == 'java'
    s.platform = RUBY_PLATFORM
    s.add_runtime_dependency "manticore", '~> 0.3'
    # Currently there is a blocking issue with the latest (3.1.1.0.9) version of 
    # `ruby-maven` # and installing jars dependencies. If you are declaring a gem 
    # in a gemfile # using the :github option it will make the bundle install crash,
    # before upgrading this gem you need to test the version with any plugins
    # that require jars.
    #
    # Ticket: https://github.com/elasticsearch/logstash/issues/2595
    s.add_runtime_dependency 'jar-dependencies', '0.1.7'
    s.add_runtime_dependency 'ruby-maven', '3.1.1.0.8'
    s.add_runtime_dependency "maven-tools", '1.0.7'
  end

  s.add_development_dependency 'logstash-devutils'
end
