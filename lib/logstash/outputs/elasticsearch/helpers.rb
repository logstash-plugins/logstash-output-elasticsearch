# Small functions that don't require a full instance of the plugin should go here.
# This will promote lightning fast tests.
#
# Methods are defined right on the module to ensure no context can be shared with the plugin instance :-)
module LogStash; module Outputs; class ElasticSearch;
  module Helpers
    INDEX_REQUIRING_TIMESTAMP = /%{\+.+\}/
    def self.predict_timestamp_issue_for(index, event)
      return false  if event.include?('@timestamp')
      return true   if index =~ INDEX_REQUIRING_TIMESTAMP
      false
    end
  end
end ; end ; end
