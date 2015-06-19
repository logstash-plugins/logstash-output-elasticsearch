require_relative "../../../spec/es_spec_helper"

shared_examples "a routing indexer" do
    let(:index) { 10.times.collect { rand(10).to_s }.join("") }
    let(:type) { 10.times.collect { rand(10).to_s }.join("") }
    let(:event_count) { 10000 + rand(500) }
    let(:flush_size) { rand(200) + 1 }
    let(:routing) { "not_implemented" }
    let(:config) { "not_implemented" }

    it "ships events" do
      insist { routing } != "not_implemented"
      insist { config } != "not_implemented"

      pipeline = LogStash::Pipeline.new(config)
      pipeline.run

      index_url = "http://#{get_host()}:#{get_port('http')}/#{index}"

      ftw = FTW::Agent.new
      ftw.post!("#{index_url}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("#{index_url}/_count?q=*&routing=#{routing}")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        cur_count = result["count"]
        insist { cur_count } == event_count
      end
    end
end

describe "(http protocol) index events with static routing", :integration => true do
  it_behaves_like 'a routing indexer' do
    let(:routing) { "test" }
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
          routing => "#{routing}"
        }
      }
      CONFIG
    }
  end
end

describe "(http_protocol) index events with fieldref in routing value", :integration => true do
  it_behaves_like 'a routing indexer' do
    let(:routing) { "test" }
    let(:config) {
      <<-CONFIG
      input {
        generator {
          message => "#{routing}"
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
          routing => "%{message}"
        }
      }
      CONFIG
    }
  end
end

describe "(transport protocol) index events with fieldref in routing value", :integration => true do
  it_behaves_like 'a routing indexer' do
    let(:routing) { "test" }
    let(:config) {
      <<-CONFIG
      input {
        generator {
          message => "#{routing}"
          count => #{event_count}
          type => "#{type}"
        }
      }
      output {
        elasticsearch {
          host => "#{get_host()}"
          port => "#{get_port('transport')}"
          protocol => "transport"
          index => "#{index}"
          flush_size => #{flush_size}
          routing => "%{message}"
        }
      }
      CONFIG
    }
  end
end
