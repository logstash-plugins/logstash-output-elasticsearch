module LogStash; module Outputs; class ElasticSearch
  module CommonConfigs
    def self.included(mod)
      # The index to write events to. This can be dynamic using the `%{foo}` syntax.
      # The default value will partition your indices by day so you can more easily
      # delete old data or only search specific date ranges.
      # Indexes may not contain uppercase characters.
      # For weekly indexes ISO 8601 format is recommended, eg. logstash-%{+xxxx.ww}.
      # LS uses Joda to format the index pattern from event timestamp.
      # Joda formats are defined http://www.joda.org/joda-time/apidocs/org/joda/time/format/DateTimeFormat.html[here].
      mod.config :index, :validate => :string, :default => "logstash-%{+YYYY.MM.dd}"

      # The document type to write events to. Generally you should try to write only
      # similar events to the same 'type'. String expansion `%{foo}` works here.
      # Unless you set 'document_type', the event 'type' will be used if it exists
      # otherwise the document type will be assigned the value of 'logs'
      mod.config :document_type, :validate => :string

      # Starting in Logstash 1.3 (unless you set option `manage_template` to false)
      # a default mapping template for Elasticsearch will be applied, if you do not
      # already have one set to match the index pattern defined (default of
      # `logstash-%{+YYYY.MM.dd}`), minus any variables.  For example, in this case
      # the template will be applied to all indices starting with `logstash-*`
      #
      # If you have dynamic templating (e.g. creating indices based on field names)
      # then you should set `manage_template` to false and use the REST API to upload
      # your templates manually.
      mod.config :manage_template, :validate => :boolean, :default => true

      # This configuration option defines how the template is named inside Elasticsearch.
      # Note that if you have used the template management features and subsequently
      # change this, you will need to prune the old template manually, e.g.
      #
      # `curl -XDELETE <http://localhost:9200/_template/OldTemplateName?pretty>`
      #
      # where `OldTemplateName` is whatever the former setting was.
      mod.config :template_name, :validate => :string, :default => "logstash"

      # You can set the path to your own template here, if you so desire.
      # If not set, the included template will be used.
      mod.config :template, :validate => :path

      # The template_overwrite option will always overwrite the indicated template
      # in Elasticsearch with either the one indicated by template or the included one.
      # This option is set to false by default. If you always want to stay up to date
      # with the template provided by Logstash, this option could be very useful to you.
      # Likewise, if you have your own template file managed by puppet, for example, and
      # you wanted to be able to update it regularly, this option could help there as well.
      #
      # Please note that if you are using your own customized version of the Logstash
      # template (logstash), setting this to true will make Logstash to overwrite
      # the "logstash" template (i.e. removing all customized settings)
      mod.config :template_overwrite, :validate => :boolean, :default => false

      # The document ID for the index. Useful for overwriting existing entries in
      # Elasticsearch with the same ID.
      mod.config :document_id, :validate => :string

      # A routing override to be applied to all processed events.
      # This can be dynamic using the `%{foo}` syntax.
      mod.config :routing, :validate => :string

      # For child documents, ID of the associated parent.
      # This can be dynamic using the `%{foo}` syntax.
      mod.config :parent, :validate => :string, :default => nil

      # Sets the host(s) of the remote instance. If given an array it will load balance requests across the hosts specified in the `hosts` parameter.
      # Remember the `http` protocol uses the http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html#modules-http[http] address (eg. 9200, not 9300).
      #     `"127.0.0.1"`
      #     `["127.0.0.1:9200","127.0.0.2:9200"]`
      #     `["http://127.0.0.1"]`
      #     `["https://127.0.0.1:9200"]`
      #     `["https://127.0.0.1:9200/mypath"]` (If using a proxy on a subpath)
      # It is important to exclude http://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html[dedicated master nodes] from the `hosts` list
      # to prevent LS from sending bulk requests to the master nodes.  So this parameter should only reference either data or client nodes in Elasticsearch.
      mod.config :hosts, :validate => :array, :default => ["127.0.0.1"]

      # This plugin uses the bulk index API for improved indexing performance.
      # This setting defines the maximum sized bulk request Logstash will make
      # You you may want to increase this to be in line with your pipeline's batch size.
      # If you specify a number larger than the batch size of your pipeline it will have no effect,
      # save for the case where a filter increases the size of an inflight batch by outputting
      # events.
      mod.config :flush_size, :validate => :number, :default => 500

      # The amount of time since last flush before a flush is forced.
      #
      # This setting helps ensure slow event rates don't get stuck in Logstash.
      # For example, if your `flush_size` is 100, and you have received 10 events,
      # and it has been more than `idle_flush_time` seconds since the last flush,
      # Logstash will flush those 10 events automatically.
      #
      # This helps keep both fast and slow log streams moving along in
      # near-real-time.
      mod.config :idle_flush_time, :validate => :number, :default => 1

      # Set upsert content for update mode.s
      # Create a new document with this parameter as json string if `document_id` doesn't exists
      mod.config :upsert, :validate => :string, :default => ""

      # Enable `doc_as_upsert` for update mode.
      # Create a new document with source if `document_id` doesn't exist in Elasticsearch
      mod.config :doc_as_upsert, :validate => :boolean, :default => false

      #Obsolete since 4.1.0
      mod.config :max_retries, :obsolete => "This setting no longer does anything. Please remove it from your config"

      # Set script name for scripted update mode
      mod.config :script, :validate => :string, :default => ""

      # Define the type of script referenced by "script" variable
      #  inline : "script" contains inline script
      #  indexed : "script" contains the name of script directly indexed in elasticsearch
      #  file    : "script" contains the name of script stored in elasticseach's config directory
      mod.config :script_type, :validate => ["inline", 'indexed', "file"], :default => ["inline"]

      # Set the language of the used script. If not set, this defaults to painless in ES 5.0
      mod.config :script_lang, :validate => :string, :default => "painless"

      # Set variable name passed to script (scripted update)
      mod.config :script_var_name, :validate => :string, :default => "event"

      # if enabled, script is in charge of creating non-existent document (scripted update)
      mod.config :scripted_upsert, :validate => :boolean, :default => false

      # Set initial interval in seconds between bulk retries. Doubled on each retry up to `retry_max_interval`
      mod.config :retry_initial_interval, :validate => :number, :default => 2

      # Set max interval in seconds between bulk retries.
      mod.config :retry_max_interval, :validate => :number, :default => 64

      #Obsolete since 4.1.0
      mod.config :retry_max_items, :obsolete => "This setting no longer does anything. Please remove it from your config"

      # The number of times Elasticsearch should internally retry an update/upserted document
      # See the https://www.elastic.co/guide/en/elasticsearch/guide/current/partial-updates.html[partial updates]
      # for more info
      mod.config :retry_on_conflict, :validate => :number, :default => 1

      # Set which ingest pipeline you wish to execute for an event
      mod.config :pipeline, :validate => :string, :default => nil
    end
  end
end end end
