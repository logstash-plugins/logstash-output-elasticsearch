
require 'logstash/plugin_mixins/ca_trusted_fingerprint_support'

module LogStash; module PluginMixins; module ElasticSearch
  module APIConfigs

    # This module defines common options that can be reused by alternate elasticsearch output plugins such as the elasticsearch_data_streams output.

    DEFAULT_HOST = ::LogStash::Util::SafeURI.new("//127.0.0.1")
    DEFAULT_ZIP_LEVEL = 1

    CONFIG_PARAMS = {
        # Username to authenticate to a secure Elasticsearch cluster
        :user => { :validate => :string },
        # Password to authenticate to a secure Elasticsearch cluster
        :password => { :validate => :password },

        # Authenticate using Elasticsearch API key.
        # format is id:api_key (as returned by https://www.elastic.co/guide/en/elasticsearch/reference/current/security-api-create-api-key.html[Create API key])
        :api_key => { :validate => :password },

        # Cloud authentication string ("<username>:<password>" format) is an alternative for the `user`/`password` configuration.
        #
        # For more details, check out the https://www.elastic.co/guide/en/logstash/current/connecting-to-cloud.html#_cloud_auth[cloud documentation]
        :cloud_auth => { :validate => :password },

        # The document ID for the index. Useful for overwriting existing entries in
        # Elasticsearch with the same ID.
        :document_id => { :validate => :string },

        # HTTP Path at which the Elasticsearch server lives. Use this if you must run Elasticsearch behind a proxy that remaps
        # the root path for the Elasticsearch HTTP API lives.
        # Note that if you use paths as components of URLs in the 'hosts' field you may
        # not also set this field. That will raise an error at startup
        :path => { :validate => :string },

        # HTTP Path to perform the _bulk requests to
        # this defaults to a concatenation of the path parameter and "_bulk"
        :bulk_path => { :validate => :string },

        # Pass a set of key value pairs as the URL query string. This query string is added
        # to every host listed in the 'hosts' configuration. If the 'hosts' list contains
        # urls that already have query strings, the one specified here will be appended.
        :parameters => { :validate => :hash },

        # Enable SSL/TLS secured communication to Elasticsearch cluster. Leaving this unspecified will use whatever scheme
        # is specified in the URLs listed in 'hosts'. If no explicit protocol is specified plain HTTP will be used.
        # If SSL is explicitly disabled here the plugin will refuse to start if an HTTPS URL is given in 'hosts'
        :ssl => { :validate => :boolean, :deprecated => "Set 'ssl_enabled' instead." },

        # Enable SSL/TLS secured communication to Elasticsearch cluster. Leaving this unspecified will use whatever scheme
        # is specified in the URLs listed in 'hosts'. If no explicit protocol is specified plain HTTP will be used.
        # If SSL is explicitly disabled here the plugin will refuse to start if an HTTPS URL is given in 'hosts'
        :ssl_enabled => { :validate => :boolean },

        # Option to validate the server's certificate. Disabling this severely compromises security.
        # For more information on disabling certificate verification please read
        # https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf
        :ssl_certificate_verification => { :validate => :boolean, :default => true, :deprecated => "Set 'ssl_verification_mode' instead." },

        # Options to verify the server's certificate.
        # "full": validates that the provided certificate has an issue date that’s within the not_before and not_after dates;
        # chains to a trusted Certificate Authority (CA); has a hostname or IP address that matches the names within the certificate.
        # "none": performs no certificate validation. Disabling this severely compromises security (https://www.cs.utexas.edu/~shmat/shmat_ccs12.pdf)
        :ssl_verification_mode => { :validate => %w[full none], :default => 'full' },

        # The .cer or .pem file to validate the server's certificate
        :cacert => { :validate => :path, :deprecated => "Set 'ssl_certificate_authorities' instead." },

        # The .cer or .pem files to validate the server's certificate
        :ssl_certificate_authorities => { :validate => :path, :list => true },

        # One or more hex-encoded SHA256 fingerprints to trust as Certificate Authorities
        :ca_trusted_fingerprint => LogStash::PluginMixins::CATrustedFingerprintSupport,

        # The JKS truststore to validate the server's certificate.
        # Use either `:truststore` or `:cacert`
        :truststore => { :validate => :path, :deprecated => "Set 'ssl_truststore_path' instead." },

        # The JKS truststore to validate the server's certificate.
        # Use either `:ssl_truststore_path` or `:ssl_certificate_authorities`
        :ssl_truststore_path => { :validate => :path },

        # The format of the truststore file. It must be either jks or pkcs12
        :ssl_truststore_type => { :validate => %w[pkcs12 jks] },

        # Set the truststore password
        :truststore_password => { :validate => :password, :deprecated => "Use 'ssl_truststore_password' instead." },

        # Set the truststore password
        :ssl_truststore_password => { :validate => :password },

        # The keystore used to present a certificate to the server.
        # It can be either .jks or .p12
        :keystore => { :validate => :path, :deprecated => "Set 'ssl_keystore_path' instead." },

        # The keystore used to present a certificate to the server.
        # It can be either .jks or .p12
        :ssl_keystore_path => { :validate => :path },

        # The format of the keystore file. It must be either jks or pkcs12
        :ssl_keystore_type => { :validate => %w[pkcs12 jks] },

        # Set the keystore password
        :keystore_password => { :validate => :password, :deprecated => "Set 'ssl_keystore_password' instead." },

        # Set the keystore password
        :ssl_keystore_password => { :validate => :password },

        :ssl_supported_protocols => { :validate => ['TLSv1.1', 'TLSv1.2', 'TLSv1.3'], :default => [], :list => true },

        # OpenSSL-style X.509 certificate certificate to authenticate the client
        :ssl_certificate => { :validate => :path },

        # OpenSSL-style RSA private key to authenticate the client
        :ssl_key => { :validate => :path },

        # The list of cipher suites to use, listed by priorities.
        # Supported cipher suites vary depending on which version of Java is used.
        :ssl_cipher_suites => { :validate => :string, :list => true },

        # This setting asks Elasticsearch for the list of all cluster nodes and adds them to the hosts list.
        # Note: This will return ALL nodes with HTTP enabled (including master nodes!). If you use
        # this with master nodes, you probably want to disable HTTP on them by setting
        # `http.enabled` to false in their elasticsearch.yml. You can either use the `sniffing` option or
        # manually enter multiple Elasticsearch hosts using the `hosts` parameter.
        :sniffing => { :validate => :boolean, :default => false },

        # How long to wait, in seconds, between sniffing attempts
        :sniffing_delay => { :validate => :number, :default => 5 },

        # HTTP Path to be used for the sniffing requests
        # the default value is computed by concatenating the path value and "_nodes/http"
        # if sniffing_path is set it will be used as an absolute path
        # do not use full URL here, only paths, e.g. "/sniff/_nodes/http"
        :sniffing_path => { :validate => :string },

        # Set the address of a forward HTTP proxy.
        # This used to accept hashes as arguments but now only accepts
        # arguments of the URI type to prevent leaking credentials.
        :proxy => { :validate => :uri }, # but empty string is allowed

        # Set the timeout, in seconds, for network operations and requests sent Elasticsearch. If
        # a timeout occurs, the request will be retried.
        :timeout => { :validate => :number, :default => 60 },

        # Deprecated, refer to `silence_errors_in_log`.
        :failure_type_logging_whitelist => { :validate => :array, :default => [] },

        # Defines the list of Elasticsearch errors that you don't want to log.
        # A useful example is when you want to skip all 409 errors
        # which are `version_conflict_engine_exception`.
        # Deprecates `failure_type_logging_whitelist`.
        :silence_errors_in_log => { :validate => :array, :default => [] },

        # While the output tries to reuse connections efficiently we have a maximum.
        # This sets the maximum number of open connections the output will create.
        # Setting this too low may mean frequently closing / opening connections
        # which is bad.
        :pool_max => { :validate => :number, :default => 1000 },

        # While the output tries to reuse connections efficiently we have a maximum per endpoint.
        # This sets the maximum number of open connections per endpoint the output will create.
        # Setting this too low may mean frequently closing / opening connections
        # which is bad.
        :pool_max_per_route => { :validate => :number, :default => 100 },

        # HTTP Path where a HEAD request is sent when a backend is marked down
        # the request is sent in the background to see if it has come back again
        # before it is once again eligible to service requests.
        # If you have custom firewall rules you may need to change this
        :healthcheck_path => { :validate => :string },

        # How frequently, in seconds, to wait between resurrection attempts.
        # Resurrection is the process by which backend endpoints marked 'down' are checked
        # to see if they have come back to life
        :resurrect_delay => { :validate => :number, :default => 5 },

        # How long to wait before checking if the connection is stale before executing a request on a connection using keepalive.
        # You may want to set this lower, if you get connection errors regularly
        # Quoting the Apache commons docs (this client is based Apache Commmons):
        # 'Defines period of inactivity in milliseconds after which persistent connections must
        # be re-validated prior to being leased to the consumer. Non-positive value passed to
        # this method disables connection validation. This check helps detect connections that
        # have become stale (half-closed) while kept inactive in the pool.'
        # See https://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/conn/PoolingHttpClientConnectionManager.html#setValidateAfterInactivity(int)[these docs for more info]
        :validate_after_inactivity => { :validate => :number, :default => 10000 },

        # Enable gzip compression on requests. Note that response compression is on by default for Elasticsearch v5.0 and beyond
        # Set `true` to enable compression with level 1
        # Set `false` to disable compression with level 0
        :http_compression => { :validate => :boolean, :default => true, :deprecated => "Set 'compression_level' instead." },

        # Number `1` ~ `9` are the gzip compression level
        # Set `0` to disable compression
        # Set `1` (best speed) to `9` (best compression) to use compression
        :compression_level => { :validate => [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ], :default => DEFAULT_ZIP_LEVEL },

        # Custom Headers to send on each request to elasticsearch nodes
        :custom_headers => { :validate => :hash, :default => {} },

        # Sets the host(s) of the remote instance. If given an array it will load balance requests across the hosts specified in the `hosts` parameter.
        # Remember the `http` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http[http] address (eg. 9200, not 9300).
        #     `"127.0.0.1"`
        #     `["127.0.0.1:9200","127.0.0.2:9200"]`
        #     `["http://127.0.0.1"]`
        #     `["https://127.0.0.1:9200"]`
        #     `["https://127.0.0.1:9200/mypath"]` (If using a proxy on a subpath)
        # It is important to exclude http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[dedicated master nodes] from the `hosts` list
        # to prevent LS from sending bulk requests to the master nodes.  So this parameter should only reference either data or client nodes in Elasticsearch.
        #
        # Any special characters present in the URLs here MUST be URL escaped! This means `#` should be put in as `%23` for instance.
        :hosts => { :validate => :uri, :default => [ DEFAULT_HOST ], :list => true },

        # Cloud ID, from the Elastic Cloud web console. If set `hosts` should not be used.
        #
        # For more details, check out the https://www.elastic.co/guide/en/logstash/current/connecting-to-cloud.html#_cloud_id[cloud documentation]
        :cloud_id => { :validate => :string },

        # Set initial interval in seconds between bulk retries. Doubled on each retry up to `retry_max_interval`
        :retry_initial_interval => { :validate => :number, :default => 2 },

        # Set max interval in seconds between bulk retries.
        :retry_max_interval => { :validate => :number, :default => 64 },

        # List extra HTTP's error codes that are considered valid to move the events into the dead letter queue.
        # It's considered a configuration error to re-use the same predefined codes for success, DLQ or conflict.
        # The option accepts a list of natural numbers corresponding to HTTP errors codes.
        :dlq_custom_codes => { :validate => :number, :list => true, :default => [] },

        # if enabled, failed index name interpolation events go into dead letter queue.
        :dlq_on_failed_indexname_interpolation => { :validate => :boolean, :default => true }
    }.freeze

    def self.included(base)
      CONFIG_PARAMS.each do |name, opts|
        if opts.kind_of?(Module)
          base.include(opts)
        else
          base.config(name, opts)
        end
      end
    end
  end
end; end; end
