## 5.1.0
- Add check_connection_timeout parameter (default 10m)
- Set default timeout to 60s

## 5.0.0
- Breaking Change: Index template for 5.0 has been changed to reflect Elasticsearch's mapping changes. Most importantly,
the subfield for string multi-fields has changed from `.raw` to `.keyword` to match ES default behavior. ([#386](https://github.com/logstash-plugins/logstash-output-elasticsearch/issues/386))

**Users installing ES 5.x and LS 5.x**
This change will not affect you and you will continue to use the ES defaults.

**Users upgrading from LS 2.x to LS 5.x with ES 5.x**
LS will not force upgrade the template, if `logstash` template already exists. This means you will still use
`.raw` for sub-fields coming from 2.x. If you choose to use the new template, you will have to reindex your data after
the new template is installed.

## 4.1.3
- Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 4.1.2

- Added a configuration called failure_type_logging_whitelist which takes a list of strings, that are error types from elasticsearch, so we prevent logging WARN if elasticsearch fails with that action. See https://github.com/logstash-plugins/logstash-output-elasticsearch/issues/423

## 4.1.1
- Fix bug where setting credentials would cause fatal errors. See https://github.com/logstash-plugins/logstash-output-elasticsearch/issues/441

## 4.1.0
- breaking,config: Removed obsolete config `host` and `port`. Please use the `hosts` config with the `[host:port]` syntax.
- breaking,config: Removed obsolete config `index_type`. Please use `document_type` instead.
- breaking,config: Set config `max_retries` and `retry_max_items` as obsolete

## 4.0.0
 - Make this plugin threadsafe. Workers no longer needed or supported
 - Add pool_max and pool_max_per_route options

## 3.0.2
 - Fix issues where URI based paths in 'hosts' would not function correctly

## 3.0.1
 - Republish all the gems under jruby.

## 3.0.0
 - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141

## 2.7.0
 - Add `pipeline` configuration option for setting an ingest pipeline to run upon indexing


## 2.6.2
 - Fix bug where update index actions would not work with events with 'data' field

## 2.6.1
 - Add 'retry_on_conflict' configuration option which should have been here from the beginning

## 2.5.2
 - Fix bug with update document with doc_as_upsert and scripting (#364, #359)
 - Make error messages more verbose and easier to parse by humans
 - Retryable failures are now logged at the info level instead of warning. (issue #372)

## 2.5.1
 - Fix bug where SSL would sometimes not be enabled

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
