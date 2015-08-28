require "bundler/gem_helper"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

@files=[]
require "logstash/devutils/rake"

namespace :vendor do
  require 'jar_installer'

  desc "install jars"
  task :install_jars do
    ENV['JARS_HOME'] = File.join(File.dirname(__FILE__), "vendor")
    Jars::JarInstaller.vendor_jars
  end

end

desc "Build .gem into the pkg directory."
task "build" => ["vendor"] do
  gem_helper = Bundler::GemHelper.new(File.dirname(__FILE__))
  gem_helper.build_gem
end

desc "Process any vendor files required for this plugin"
task "vendor" => [ "vendor:files", "vendor:install_jars" ]
