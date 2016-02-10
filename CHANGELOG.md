## 2.5.0
 - Host settings now are more robust to bad input
 - Host settings can now take full URLs

## 2.4.2
 - Make flush_size actually cap the batch size in LS 2.2+

## 2.4.1
 - Used debug level instead of info when emitting flush log message
 - Updated docs about template

## 2.4.0
 - Scripted update support courtesy of @Da-Wei

## 2.3.2
 - Fix bug where max_retry_interval was not respected for HTTP error codes

## 2.3.1
 - Bump manticore dependenvy to 0.5.2

## 2.3.0
 - Now retry too busy and service unavailable errors infinitely.
 - Never retry conflict errors
 - Fix broken delete verb that would fail due to sending body with verb

## 2.2.0
 - Serialize access to the connection pool in es-ruby client
 - Add support for parent relationship

## 2.1.5
 - Sprintf style 'action' parameters no longer raise a LogStash::ConfigurationError

## 2.1.4
 - Improved the default template to disable fielddata on analyzed string fields. #309
 - Dependend on logstash-core 2.0.0 released version, rather than RC1

## 2.1.3
 - Improved the default template to use doc_values wherever possible.
 - Template contains example mappings for every numeric type. You must map your
   own fields to make use of anything other than long and double.

## 2.1.2
 - Fixed dependencies (#280)
 - Fixed an RSpec test (#281)

## 2.1.1
 - Made host config obsolete.

## 2.1.0
 - New setting: timeout. This lets you control the behavior of a slow/stuck
   request to Elasticsearch that could be, for example, caused by network,
   firewall, or load balancer issues.

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

## 2.0.0-beta2
 - Massive internal refactor of client handling
 - Background HTTP sniffing support
 - Reduced bulk request size to 500 from 5000 (better memory utilization)
 - Removed 'host' config option. Now use 'hosts'

## 2.0.0-beta
 - Only support HTTP Protocol
 - Removed support for node and transport protocols (now in logstash-output-elasticsearch_java)

## 1.0.7
 - Add update API support

## 1.0.6
 - Fix warning about Concurrent lib deprecation

## 1.0.4
 - Update to Elasticsearch 1.7

## 1.0.3
 - Add HTTP proxy support

## 1.0.2
 - Upgrade Manticore HTTP Client

## 1.0.1
 - Allow client certificates

## 0.2.9
 - Add 'path' parameter for ES HTTP hosts behind a proxy on a subpath

## 0.2.8 (June 12, 2015)
 - Add option to enable and disable SSL certificate verification during handshake (#160)
 - Doc improvements for clarifying round robin behavior using hosts config

## 0.2.7 (May 28, 2015)
 - Bump es-ruby version to 1.0.10

## 0.2.6 (May 28, 2015)
 - Disable timeouts when using http protocol which would cause bulk requests to fail (#103)
