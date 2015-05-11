require_relative "../../../spec/es_spec_helper"

shared_examples "an indexer" do
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:flush_size) { rand(200) + 1 }
    let(:config) { "not implemented" }

    it "ships events" do
      insist { config } != "not implemented"

      pipeline = LogStash::Pipeline.new(config)
      pipeline.run

      index_url = "http://#{get_host}:#{get_port('http')}/#{index}"

      ftw = FTW::Agent.new
      ftw.post!("#{index_url}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("#{index_url}/_count?q=*")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        cur_count = result["count"]
        insist { cur_count } == event_count
      end

      response = ftw.get!("#{index_url}/_search?q=*&size=1000")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      result["hits"]["hits"].each do |doc|
        insist { doc["_type"] } == type
        insist { doc["_index"] } == index
      end
    end
end

describe "an indexer with custom index_type", :integration => true do
  it_behaves_like "an indexer" do
    let(:config) {
      <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
          type => "#{type}"
        }
      }
      output {
        elasticsearch {
          host => "#{get_host()}"
          port => "#{get_port('http')}"
          protocol => "http"
          index => "#{index}"
          flush_size => #{flush_size}
        }
      }
      CONFIG
    }
  end
end

describe "an indexer with no type value set (default to logs)", :integration => true do
  it_behaves_like "an indexer" do
    let(:type) { "logs" }
    let(:config) {
      <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
        }
      }
      output {
        elasticsearch {
          host => "#{get_host()}"
          port => "#{get_port('http')}"
          protocol => "http"
          index => "#{index}"
          flush_size => #{flush_size}
        }
      }
      CONFIG
    }
  end
end
