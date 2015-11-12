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
# the https://www.elastic.co/guide/en/logstash/2.0/plugins-outputs-elasticsearch_java.html[logstash-output-elasticsearch_java] plugin.
#
# You can learn more about Elasticsearch at <https://www.elastic.co/products/elasticsearch>
#
# ==== Retry Policy
#
# This plugin uses the Elasticsearch bulk API to optimize its imports into Elasticsearch. These requests may experience
# either partial or total failures. Events are retried if they fail due to either a network error or the status codes
# 429 (the server is busy), 409 (Version Conflict), or 503 (temporary overloading/maintenance).
#
# The retry policy's logic can be described as follows:
#
# - Block and retry all events in the bulk response that experience transient network exceptions until
#   a successful submission is received by Elasticsearch.
# - Retry the subset of sent events which resulted in ES errors of a retryable nature.
# - Events which returned retryable error codes will be pushed onto a separate queue for
#   retrying events. Events in this queue will be retried a maximum of 5 times by default (configurable through :max_retries).
#   The size of this queue is capped by the value set in :retry_max_items.
# - Events from the retry queue are submitted again when the queue reaches its max size or when
#   the max interval time is reached. The max interval time is configurable via :retry_max_interval.
# - Events which are not retryable or have reached their max retry count are logged to stderr.
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

  # Username to authenticate to a secure Elasticsearch cluster
  config :user, :validate => :string
  # Password to authenticate to a secure Elasticsearch cluster
  config :password, :validate => :password

  # HTTP Path at which the Elasticsearch server lives. Use this if you must run Elasticsearch behind a proxy that remaps
  # the root path for the Elasticsearch HTTP API lives.
  config :path, :validate => :string, :default => "/"

  # Enable SSL/TLS secured communication to Elasticsearch cluster
  config :ssl, :validate => :boolean, :default => false

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

  # Set max retry for each event. The total time spent blocked on retries will be
  # (max_retries * retry_max_interval). This may vary a bit if Elasticsearch is very slow to respond
  config :max_retries, :validate => :number, :default => 3

  # Set max interval between bulk retries.
  config :retry_max_interval, :validate => :number, :default => 2

  # DEPRECATED This setting no longer does anything. If you need to change the number of retries in flight
  # try increasing the total number of workers to better handle this.
  config :retry_max_items, :validate => :number, :default => 500, :deprecated => true

  # Set the address of a forward HTTP proxy.
  # Can be either a string, such as `http://localhost:123` or a hash in the form
  # of `{host: 'proxy.org' port: 80 scheme: 'http'}`.
  # Note, this is NOT a SOCKS proxy, but a plain HTTP proxy
  config :proxy

  # Enable `doc_as_upsert` for update mode.
  # Create a new document with source if `document_id` doesn't exist in Elasticsearch
  config :doc_as_upsert, :validate => :boolean, :default => false

  # Set the timeout for network operations and requests sent Elasticsearch. If
  # a timeout occurs, the request will be retried.
  config :timeout, :validate => :number

  def build_client
    @client = ::LogStash::Outputs::ElasticSearch::HttpClientBuilder.build(@logger, @hosts, params)
  end

  @@plugins = Gem::Specification.find_all{|spec| spec.name =~ /logstash-output-elasticsearch-/ }

  @@plugins.each do |plugin|
    name = plugin.name.split('-')[-1]
    require "logstash/outputs/elasticsearch/#{name}"
  end

end # class LogStash::Outputs::Elasticsearch
