require "logstash/devutils/rspec/spec_helper"

module ESHelper
  def get_host_port
    "127.0.0.1:9200"
  end

  def get_client
    ::Manticore::Client.new()
  end
  
  def send_request(method, location, params={})
    url = location !~ /^https?:\/\// ? "http://#{get_host_port}/#{location}" : location
    
    if params[:body].is_a?(Hash)
      params[:body] = ::LogStash::Json.dump(params[:body])
    end
    
    resp = get_client.send(method, url, params)
    resp.call # by default resp is lazy
    resp
  end
  
  def send_delete_all()
    send_request(:delete, "/_template/*")
    send_request(:delete, "/*")
    send_refresh
  end
  
  def send_refresh()
    send_request(:post, "/_refresh")
  end
  
  def send_json_request(*args)
    body = send_request(*args).body
    ::LogStash::Json.load(body)
  rescue ::LogStash::Json::ParserError => e
    raise "Caught a json parse error #{e} for args #{args}. Response: #{body}"
  end
  
  def search_query_string(string)
    send_refresh
    send_json_request(:get, "/_search", query: {:q => string})
  end
end

RSpec.configure do |config|
  config.include ESHelper
end
