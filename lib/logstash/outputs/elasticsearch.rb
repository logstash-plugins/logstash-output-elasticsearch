# encoding: utf-8
require "logstash/namespace"
require "logstash/environment"
require "logstash/outputs/base"
require "logstash/json"
require "concurrent"
require "stud/buffer"
require "socket" # for Socket.gethostname
require "thread" # for safe queueing
require "uri" # for escaping user input

# This plugin is the recommended method of storing logs in Elasticsearch.
# If you plan on using the Kibana web interface, you'll want to use this output.
#
# This output only speaks the HTTP protocol. HTTP is the preferred protocol for interacting with Elasticsearch as of Logstash 2.0.
# We strongly encourage the use of HTTP over the node protocol for a number of reasons. HTTP is only marginally slower,
# yet far easier to administer and work with. When using the HTTP protocol one may upgrade Elasticsearch versions without having
# to upgrade Logstash in lock-step. For those still wishing to use the node or transport protocols please see
# the <<plugins-outputs-elasticsearch_java,elasticsearch_java output plugin>>.
#
# You can learn more about Elasticsearch at <https://www.elastic.co/products/elasticsearch>
#
# ==== Retry Policy
#
# The retry policy has changed significantly in the 2.2.0 release.
# This plugin uses the Elasticsearch bulk API to optimize its imports into Elasticsearch. These requests may experience
# either partial or total failures.
#
# The following errors are retried infinitely:
#
# - Network errors (inability to connect)
# - 429 (Too many requests) and
# - 503 (Service unavailable) errors
#
# NOTE: 409 exceptions are no longer retried. Please set a higher `retry_on_conflict` value if you experience 409 exceptions.
# It is more performant for Elasticsearch to retry these exceptions than this plugin.
#
# ==== DNS Caching
#
# This plugin uses the JVM to lookup DNS entries and is subject to the value of https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html[networkaddress.cache.ttl],
# a global setting for the JVM.
#
# As an example, to set your DNS TTL to 1 second you would set
# the `LS_JAVA_OPTS` environment variable to `-Dnetwordaddress.cache.ttl=1`.
#
# Keep in mind that a connection with keepalive enabled will
# not reevaluate its DNS value while the keepalive is in effect.
class LogStash::Outputs::ElasticSearch < LogStash::Outputs::Base
  require "logstash/outputs/elasticsearch/http_client"
  require "logstash/outputs/elasticsearch/http_client_builder"
  require "logstash/outputs/elasticsearch/common_configs"
  require "logstash/outputs/elasticsearch/common"

  # Protocol agnostic (i.e. non-http, non-java specific) configs go here
  include(LogStash::Outputs::ElasticSearch::CommonConfigs)

  # Protocol agnostic methods
  include(LogStash::Outputs::ElasticSearch::Common)

  config_name "elasticsearch"

  # The Elasticsearch action to perform. Valid actions are:
  #
  # - index: indexes a document (an event from Logstash).
  # - delete: deletes a document by id (An id is required for this action)
  # - create: indexes a document, fails if a document by that id already exists in the index.
  # - update: updates a document by id. Update has a special case where you can upsert -- update a
  #   document if not already present. See the `upsert` option
  # - A sprintf style string to change the action based on the content of the event. The value `%{[foo]}`
  #   would use the foo field for the action
  #
  # For more details on actions, check out the http://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html[Elasticsearch bulk API documentation]
  config :action, :validate => :string, :default => "index"

  # Username to authenticate to a secure Elasticsearch cluster
  config :user, :validate => :string
  # Password to authenticate to a secure Elasticsearch cluster
  config :password, :validate => :password

  # HTTP Path at which the Elasticsearch server lives. Use this if you must run Elasticsearch behind a proxy that remaps
  # the root path for the Elasticsearch HTTP API lives.
  config :path, :validate => :string, :default => "/"

  # Enable SSL/TLS secured communication to Elasticsearch cluster. Leaving this unspecified will use whatever scheme
  # is specified in the URLs listed in 'hosts'. If no explicit protocol is specified plain HTTP will be used.
  # If SSL is explicitly disabled here the plugin will refuse to start if an HTTPS URL is given in 'hosts'
  config :ssl, :validate => :boolean

  # Option to validate the server's certificate. Disabling this severely compromises security.
  # For more information on disabling certificate verification please read
  # https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf
  config :ssl_certificate_verification, :validate => :boolean, :default => true

  # The .cer or .pem file to validate the server's certificate
  config :cacert, :validate => :path

  # The JKS truststore to validate the server's certificate.
  # Use either `:truststore` or `:cacert`
  config :truststore, :validate => :path

  # Set the truststore password
  config :truststore_password, :validate => :password

  # The keystore used to present a certificate to the server.
  # It can be either .jks or .p12
  config :keystore, :validate => :path

  # Set the truststore password
  config :keystore_password, :validate => :password

  # This setting asks Elasticsearch for the list of all cluster nodes and adds them to the hosts list.
  # Note: This will return ALL nodes with HTTP enabled (including master nodes!). If you use
  # this with master nodes, you probably want to disable HTTP on them by setting
  # `http.enabled` to false in their elasticsearch.yml. You can either use the `sniffing` option or
  # manually enter multiple Elasticsearch hosts using the `hosts` parameter.
  config :sniffing, :validate => :boolean, :default => false

  # How long to wait, in seconds, between sniffing attempts
  config :sniffing_delay, :validate => :number, :default => 5

  # Set the address of a forward HTTP proxy.
  # Can be either a string, such as `http://localhost:123` or a hash in the form
  # of `{host: 'proxy.org' port: 80 scheme: 'http'}`.
  # Note, this is NOT a SOCKS proxy, but a plain HTTP proxy
  config :proxy

  # Set the timeout for network operations and requests sent Elasticsearch. If
  # a timeout occurs, the request will be retried.
  config :timeout, :validate => :number

  def build_client
    @client = ::LogStash::Outputs::ElasticSearch::HttpClientBuilder.build(@logger, @hosts, params)
  end

  def close
    @stopping.make_true
    @client.stop_sniffing!
    @buffer.stop
  end

  @@plugins = Gem::Specification.find_all{|spec| spec.name =~ /logstash-output-elasticsearch-/ }

  @@plugins.each do |plugin|
    name = plugin.name.split('-')[-1]
    require "logstash/outputs/elasticsearch/#{name}"
  end

end # class LogStash::Outputs::Elasticsearch
