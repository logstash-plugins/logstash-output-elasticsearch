{
  "template" : "logstash-*",
  "settings" : {
    "index.refresh_interval" : "5s"
  },
  "mappings" : {
    "_default_" : {
      "_all" : {"enabled" : true, "omit_norms" : true},
      "dynamic_templates" : [ {
        "message_field" : {
          "match" : "message",
          "match_mapping_type" : "string",
          "mapping" : {
            "type" : "string", "index" : "analyzed", "omit_norms" : true,
            "fielddata" : { "format" : "disabled" }
          }
        }
      }, {
        "string_fields" : {
          "match" : "*",
          "match_mapping_type" : "string",
          "mapping" : {
            "type" : "string", "index" : "analyzed", "omit_norms" : true,
            "fielddata" : { "format" : "disabled" },
            "fields" : {
              "raw" : {"type": "string", "index" : "not_analyzed", "ignore_above" : 256}
            }
          }
        }
      } ],
      "properties" : {
        "@timestamp": { "type": "date" },
        "@version": { "type": "string", "index": "not_analyzed" },
        "geoip"  : {
          "dynamic": true,
          "properties" : {
            "ip": { "type": "ip" },
            "location" : { "type" : "geo_point" },
            "latitude" : { "type" : "float" },
            "longitude" : { "type" : "float" }
          }
        }
      }
    }
  }
}
