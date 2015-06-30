require_relative "../../../../spec/es_spec_helper"
require "logstash/outputs/elasticsearch/protocol"

describe "elasticsearch node client", :integration => true do
  # Test ElasticSearch Node Client
  # Reference: http://www.elasticsearch.org/guide/reference/modules/discovery/zen/
  
  subject { LogStash::Outputs::Elasticsearch::Protocols::NodeClient }

  it "should support hosts in both string and array" do
    # Because we defined *hosts* method in NodeClient as private,
    # we use *obj.send :method,[args...]* to call method *hosts*

    # Node client should support host in string
    # Case 1: default :host in string
    insist { subject.send :hosts, :host => "host",:port => 9300 } == "host:9300"
    # Case 2: :port =~ /^\d+_\d+$/
    insist { subject.send :hosts, :host => "host",:port => "9300-9302"} == "host:9300,host:9301,host:9302"
    # Case 3: :host =~ /^.+:.+$/
    insist { subject.send :hosts, :host => "host:9303",:port => 9300 } == "host:9303"
    # Case 4:  :host =~ /^.+:.+$/ and :port =~ /^\d+_\d+$/
    insist { subject.send :hosts, :host => "host:9303",:port => "9300-9302"} == "host:9303"

    # Node client should support host in array
    # Case 5: :host in array with single item
    insist { subject.send :hosts, :host => ["host"],:port => 9300 } == ("host:9300")
    # Case 6: :host in array with more than one items
    insist { subject.send :hosts, :host => ["host1","host2"],:port => 9300 } == "host1:9300,host2:9300"
    # Case 7: :host in array with more than one items and :port =~ /^\d+_\d+$/
    insist { subject.send :hosts, :host => ["host1","host2"],:port => "9300-9302" } == "host1:9300,host1:9301,host1:9302,host2:9300,host2:9301,host2:9302"
    # Case 8: :host in array with more than one items and some :host =~ /^.+:.+$/
    insist { subject.send :hosts, :host => ["host1","host2:9303"],:port => 9300 } == "host1:9300,host2:9303"
    # Case 9: :host in array with more than one items, :port =~ /^\d+_\d+$/ and some :host =~ /^.+:.+$/
    insist { subject.send :hosts, :host => ["host1","host2:9303"],:port => "9300-9302" } == "host1:9300,host1:9301,host1:9302,host2:9303"
  end
end
