require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/protocol"
require "java"

describe LogStash::Outputs::Elasticsearch::Protocols::NodeClient do
  context "successful" do
    it "should map correctly" do
      index_response = org.elasticsearch.action.index.IndexResponse.new("my_index", "my_type", "my_id", 123, true)
      update_response = org.elasticsearch.action.update.UpdateResponse.new("my_index", "my_type", "my_id", 123, false)
      delete_response = org.elasticsearch.action.delete.DeleteResponse.new("my_index", "my_type", "my_id", 123, true)
      bulk_item_response_index = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "index", index_response)
      bulk_item_response_update = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "update", update_response)
      bulk_item_response_delete = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "delete", delete_response)
      bulk_response = org.elasticsearch.action.bulk.BulkResponse.new([bulk_item_response_index, bulk_item_response_update, bulk_item_response_delete], 0)
      ret = LogStash::Outputs::Elasticsearch::Protocols::NodeClient.normalize_bulk_response(bulk_response)
      insist { ret } == {"errors" => false}
    end
  end

  context "contains failures" do
    it "should map correctly" do
      failure = org.elasticsearch.action.bulk.BulkItemResponse::Failure.new("my_index", "my_type", "my_id", "error message", org.elasticsearch.rest.RestStatus::BAD_REQUEST)
      bulk_item_response_index = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "index", failure)
      bulk_item_response_update = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "update", failure)
      bulk_item_response_delete = org.elasticsearch.action.bulk.BulkItemResponse.new(32, "delete", failure)
      bulk_response = org.elasticsearch.action.bulk.BulkResponse.new([bulk_item_response_index, bulk_item_response_update, bulk_item_response_delete], 0)
      actual = LogStash::Outputs::Elasticsearch::Protocols::NodeClient.normalize_bulk_response(bulk_response)
      insist { actual } == {"errors" => true, "statuses" => [400, 400, 400]}
    end
  end
end

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
