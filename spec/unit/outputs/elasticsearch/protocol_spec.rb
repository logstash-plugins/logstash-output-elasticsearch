require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/protocol"
require "java"

describe LogStash::Outputs::Elasticsearch::Protocols::HTTPClient do
  context "successful" do
    it "should map correctly" do
      bulk_response = {"took"=>74, "errors"=>false, "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
                                                                          "_type"=>"logs", "_id"=>"AUxTS2C55Jrgi-hC6rQF",
                                                                          "_version"=>1, "status"=>201}}]} 
      actual = LogStash::Outputs::Elasticsearch::Protocols::HTTPClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> false}
    end
  end

  context "contains failures" do
    it "should map correctly" do
      bulk_response = {"took"=>71, "errors"=>true,
                       "items"=>[{"create"=>{"_index"=>"logstash-2014.11.17",
                                             "_type"=>"logs", "_id"=>"AUxTQ_OI5Jrgi-hC6rQB", "status"=>400,
                                             "error"=>"MapperParsingException[failed to parse]..."}}]}
      actual = LogStash::Outputs::Elasticsearch::Protocols::HTTPClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors"=> true, "statuses"=> [400]}
    end
  end
end
