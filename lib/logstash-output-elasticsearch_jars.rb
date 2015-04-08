# encoding: utf-8
require 'logstash/environment'

ROOT_DIR   = File.expand_path(File.join(File.dirname(__FILE__), ".."))
LogStash::Environment.load_runtime_jars! File.join(ROOT_DIR, "vendor")
