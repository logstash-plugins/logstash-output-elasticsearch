require "logstash/devutils/rspec/spec_helper"
require "ftw"
require "logstash/plugin"
require "logstash/json"
require "stud/try"

describe "outputs/elasticsearch" do

  it "should register" do
    output = LogStash::Plugin.lookup("output", "elasticsearch").new("embedded" => "false", "protocol" => "transport", "manage_template" => "false")

    # register will try to load jars and raise if it cannot find jars
    expect {output.register}.to_not raise_error
  end

  describe "ship lots of events w/ default index_type", :elasticsearch => true do
    # Generate a random index name
    index = 10.times.collect { rand(10).to_s }.join("")
    type = 10.times.collect { rand(10).to_s }.join("")

    # Write about 10000 events. Add jitter to increase likeliness of finding
    # boundary-related bugs.
    event_count = 10000 + rand(500)
    flush_size = rand(200) + 1

    config <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
          type => "#{type}"
        }
      }
      output {
        elasticsearch {
          host => "127.0.0.1"
          index => "#{index}"
          flush_size => #{flush_size}
        }
      }
    CONFIG

    agent do
      # Try a few times to check if we have the correct number of events stored
      # in ES.
      #
      # We try multiple times to allow final agent flushes as well as allowing
      # elasticsearch to finish processing everything.
      ftw = FTW::Agent.new
      ftw.post!("http://localhost:9200/#{index}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("http://127.0.0.1:9200/#{index}/_count?q=*")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        count = result["count"]
        insist { count } == event_count
      end

      response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      result["hits"]["hits"].each do |doc|
        # With no 'index_type' set, the document type should be the type
        # set on the input
        insist { doc["_type"] } == type
        insist { doc["_index"] } == index
        insist { doc["_source"]["message"] } == "hello world"
      end
    end
  end

  describe "ship lots of events w/ default index_type and fixed routing key", :elasticsearch => true do
    # Generate a random index name
    index = 10.times.collect { rand(10).to_s }.join("")
    type = 10.times.collect { rand(10).to_s }.join("")

    # Write about 10000 events. Add jitter to increase likeliness of finding
    # boundary-related bugs.
    event_count = 900
    flush_size = rand(200) + 1

    config <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => #{event_count}
          type => "#{type}"
        }
      }
      output {
        elasticsearch {
          host => "127.0.0.1"
          index => "#{index}"
          flush_size => #{flush_size}
          routing => "test"
        }
      }
    CONFIG

    agent do
      # Try a few times to check if we have the correct number of events stored
      # in ES.
      #
      # We try multiple times to allow final agent flushes as well as allowing
      # elasticsearch to finish processing everything.
      ftw = FTW::Agent.new
      ftw.post!("http://localhost:9200/#{index}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("http://127.0.0.1:9200/#{index}/_count?q=*")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        count = result["count"]
        insist { count } == event_count
      end

      response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000&?routing=test")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      count = result["count"]
      insist { count } == event_count
      result["hits"]["hits"].each do |doc|
        # With no 'index_type' set, the document type should be the type
        # set on the input
        insist { doc["_type"] } == type
        insist { doc["_index"] } == index
        insist { doc["_source"]["message"] } == "hello world"
      end

      response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000&?routing=not_test")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      count = result["count"]
      insist { count } == 0
    end
  end

  describe "node client create actions", :elasticsearch => true do
    require "logstash/outputs/elasticsearch"
    require "elasticsearch"
    let(:es) { Elasticsearch::Client.new }

    def get_es_output(action, id = nil)
      settings = {
        "manage_template" => true,
        "index" => "logstash-create",
        "template_overwrite" => true,
        "protocol" => "node",
        "host" => "localhost",
        "action" => action
      }
      settings['document_id'] = id unless id.nil?
      LogStash::Outputs::ElasticSearch.new(settings)
    end

    before :each do
      # Delete all templates first.
      # Clean ES of data before we start.
      es.indices.delete_template(:name => "*")
      # This can fail if there are no indexes, ignore failure.
      es.indices.delete(:index => "*") rescue nil
    end

    context "when action => create" do
      it "should create new documents with or without id" do
        subject = get_es_output("create", "id123")
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        es.indices.refresh
        # Wait or fail until everything's indexed.
        Stud::try(3.times) do
          r = es.search
          insist { r["hits"]["total"] } == 1
        end
      end

      it "should create new documents without id" do
        subject = get_es_output("create")
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        es.indices.refresh
        # Wait or fail until everything's indexed.
        Stud::try(3.times) do
          r = es.search
          insist { r["hits"]["total"] } == 1
        end
      end
    end

    context "when action => create_unless_exists" do
      it "should create new documents when specific id is specified" do
        subject = get_es_output("create_unless_exists", "id123")
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
        es.indices.refresh
        # Wait or fail until everything's indexed.
        Stud::try(3.times) do
          r = es.search
          insist { r["hits"]["total"] } == 1
        end
      end

      it "should fail to create a document when no id is specified" do
        event = LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0})
        action = ["create_unless_exists", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event]
        subject = get_es_output(action[0])
        subject.register
        expect { subject.flush([action]) }.to raise_error
      end

      it "should unsuccesfully submit two records with the same document id" do
        subject = get_es_output("create_unless_exists", "id123")
        subject.register
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.receive(LogStash::Event.new("message" => "sample message here")) # 400 status failure (same id)
        subject.buffer_flush(:final => true)
        es.indices.refresh
        # Wait or fail until everything's indexed.
        Stud::try(3.times) do
          r = es.search
          insist { r["hits"]["total"] } == 1
        end
      end
    end
  end

  describe "testing index_type", :elasticsearch => true do
    describe "no type value" do
      # Generate a random index name
      index = 10.times.collect { rand(10).to_s }.join("")
      event_count = 100 + rand(100)
      flush_size = rand(200) + 1

      config <<-CONFIG
        input {
          generator {
            message => "hello world"
            count => #{event_count}
          }
        }
        output {
          elasticsearch {
            host => "127.0.0.1"
            index => "#{index}"
            flush_size => #{flush_size}
          }
        }
      CONFIG

      agent do
        ftw = FTW::Agent.new
        ftw.post!("http://localhost:9200/#{index}/_refresh")

        # Wait until all events are available.
        Stud::try(10.times) do
          data = ""
          response = ftw.get!("http://127.0.0.1:9200/#{index}/_count?q=*")
          response.read_body { |chunk| data << chunk }
          result = LogStash::Json.load(data)
          count = result["count"]
          insist { count } == event_count
        end

        response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000")
        data = ""
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        result["hits"]["hits"].each do |doc|
          insist { doc["_type"] } == "logs"
        end
      end
    end

    describe "default event type value" do
      # Generate a random index name
      index = 10.times.collect { rand(10).to_s }.join("")
      event_count = 100 + rand(100)
      flush_size = rand(200) + 1

      config <<-CONFIG
        input {
          generator {
            message => "hello world"
            count => #{event_count}
            type => "generated"
          }
        }
        output {
          elasticsearch {
            host => "127.0.0.1"
            index => "#{index}"
            flush_size => #{flush_size}
          }
        }
      CONFIG

      agent do
        ftw = FTW::Agent.new
        ftw.post!("http://localhost:9200/#{index}/_refresh")

        # Wait until all events are available.
        Stud::try(10.times) do
          data = ""
          response = ftw.get!("http://127.0.0.1:9200/#{index}/_count?q=*")
          response.read_body { |chunk| data << chunk }
          result = LogStash::Json.load(data)
          count = result["count"]
          insist { count } == event_count
        end

        response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000")
        data = ""
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        result["hits"]["hits"].each do |doc|
          insist { doc["_type"] } == "generated"
        end
      end
    end
  end

  describe "action => ...", :elasticsearch => true do
    index_name = 10.times.collect { rand(10).to_s }.join("")

    config <<-CONFIG
      input {
        generator {
          message => "hello world"
          count => 100
        }
      }
      output {
        elasticsearch {
          host => "127.0.0.1"
          index => "#{index_name}"
        }
      }
    CONFIG


    agent do
      ftw = FTW::Agent.new
      ftw.post!("http://localhost:9200/#{index_name}/_refresh")

      # Wait until all events are available.
      Stud::try(10.times) do
        data = ""
        response = ftw.get!("http://127.0.0.1:9200/#{index_name}/_count?q=*")
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        count = result["count"]
        insist { count } == 100
      end

      response = ftw.get!("http://127.0.0.1:9200/#{index_name}/_search?q=*&size=1000")
      data = ""
      response.read_body { |chunk| data << chunk }
      result = LogStash::Json.load(data)
      result["hits"]["hits"].each do |doc|
        insist { doc["_type"] } == "logs"
      end
    end

    describe "default event type value", :elasticsearch => true do
      # Generate a random index name
      index = 10.times.collect { rand(10).to_s }.join("")
      event_count = 100 + rand(100)
      flush_size = rand(200) + 1

      config <<-CONFIG
        input {
          generator {
            message => "hello world"
            count => #{event_count}
            type => "generated"
          }
        }
        output {
          elasticsearch {
            host => "127.0.0.1"
            index => "#{index}"
            flush_size => #{flush_size}
          }
        }
      CONFIG

      agent do
        ftw = FTW::Agent.new
        ftw.post!("http://localhost:9200/#{index}/_refresh")

        # Wait until all events are available.
        Stud::try(10.times) do
          data = ""
          response = ftw.get!("http://127.0.0.1:9200/#{index}/_count?q=*")
          response.read_body { |chunk| data << chunk }
          result = LogStash::Json.load(data)
          count = result["count"]
          insist { count } == event_count
        end

        response = ftw.get!("http://127.0.0.1:9200/#{index}/_search?q=*&size=1000")
        data = ""
        response.read_body { |chunk| data << chunk }
        result = LogStash::Json.load(data)
        result["hits"]["hits"].each do |doc|
          insist { doc["_type"] } == "generated"
        end
      end
    end
  end

  describe "wildcard substitution in index templates", :elasticsearch => true do
    require "logstash/outputs/elasticsearch"

    let(:template) { '{"template" : "not important, will be updated by :index"}' }

    def settings_with_index(index)
      return {
        "manage_template" => true,
        "template_overwrite" => true,
        "protocol" => "http",
        "host" => "localhost",
        "index" => "#{index}"
      }
    end

    it "should substitude placeholders" do
      IO.stub(:read).with(anything) { template }
      es_output = LogStash::Outputs::ElasticSearch.new(settings_with_index("index-%{YYYY}"))
      insist { es_output.get_template['template'] } == "index-*"
    end

    it "should do nothing to an index with no placeholder" do
      IO.stub(:read).with(anything) { template }
      es_output = LogStash::Outputs::ElasticSearch.new(settings_with_index("index"))
      insist { es_output.get_template['template'] } == "index"
    end
  end

  describe "index template expected behavior", :elasticsearch => true do
    ["node", "transport", "http"].each do |protocol|
      context "with protocol => #{protocol}" do
        subject do
          require "logstash/outputs/elasticsearch"
          settings = {
            "manage_template" => true,
            "template_overwrite" => true,
            "protocol" => protocol,
            "host" => "localhost"
          }
          next LogStash::Outputs::ElasticSearch.new(settings)
        end

        before :each do
          # Delete all templates first.
          require "elasticsearch"

          # Clean ES of data before we start.
          @es = Elasticsearch::Client.new
          @es.indices.delete_template(:name => "*")

          # This can fail if there are no indexes, ignore failure.
          @es.indices.delete(:index => "*") rescue nil

          subject.register

          subject.receive(LogStash::Event.new("message" => "sample message here"))
          subject.receive(LogStash::Event.new("somevalue" => 100))
          subject.receive(LogStash::Event.new("somevalue" => 10))
          subject.receive(LogStash::Event.new("somevalue" => 1))
          subject.receive(LogStash::Event.new("country" => "us"))
          subject.receive(LogStash::Event.new("country" => "at"))
          subject.receive(LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] }))
          subject.buffer_flush(:final => true)
          @es.indices.refresh

          # Wait or fail until everything's indexed.
          Stud::try(20.times) do
            r = @es.search
            insist { r["hits"]["total"] } == 7
          end
        end

        it "permits phrase searching on string fields" do
          results = @es.search(:q => "message:\"sample message\"")
          insist { results["hits"]["total"] } == 1
          insist { results["hits"]["hits"][0]["_source"]["message"] } == "sample message here"
        end

        it "numbers dynamically map to a numeric type and permit range queries" do
          results = @es.search(:q => "somevalue:[5 TO 105]")
          insist { results["hits"]["total"] } == 2

          values = results["hits"]["hits"].collect { |r| r["_source"]["somevalue"] }
          insist { values }.include?(10)
          insist { values }.include?(100)
          reject { values }.include?(1)
        end

        it "does not create .raw field for the message field" do
          results = @es.search(:q => "message.raw:\"sample message here\"")
          insist { results["hits"]["total"] } == 0
        end

        it "creates .raw field from any string field which is not_analyzed" do
          results = @es.search(:q => "country.raw:\"us\"")
          insist { results["hits"]["total"] } == 1
          insist { results["hits"]["hits"][0]["_source"]["country"] } == "us"

          # partial or terms should not work.
          results = @es.search(:q => "country.raw:\"u\"")
          insist { results["hits"]["total"] } == 0
        end

        it "make [geoip][location] a geo_point" do
          results = @es.search(:body => { "filter" => { "geo_distance" => { "distance" => "1000km", "geoip.location" => { "lat" => 0.5, "lon" => 0.5 } } } })
          insist { results["hits"]["total"] } == 1
          insist { results["hits"]["hits"][0]["_source"]["geoip"]["location"] } == [ 0.0, 0.0 ]
        end

        it "should index stopwords like 'at' " do
          results = @es.search(:body => { "facets" => { "t" => { "terms" => { "field" => "country" } } } })["facets"]["t"]
          terms = results["terms"].collect { |t| t["term"] }

          insist { terms }.include?("us")

          # 'at' is a stopword, make sure stopwords are not ignored.
          insist { terms }.include?("at")
        end
      end
    end
  end

  describe "failures in bulk class expected behavior", :elasticsearch => true do
    let(:template) { '{"template" : "not important, will be updated by :index"}' }
    let(:event1) { LogStash::Event.new("somevalue" => 100, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
    let(:action1) { ["index", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event1] }
    let(:event2) { LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0] }, "@timestamp" => "2014-11-17T20:37:17.223Z", "@metadata" => {"retry_count" => 0}) }
    let(:action2) { ["index", {:_id=>nil, :_index=>"logstash-2014.11.17", :_type=>"logs"}, event2] }
    let(:max_retries) { 3 }

    def mock_actions_with_response(*resp)
      LogStash::Outputs::Elasticsearch::Protocols::HTTPClient
        .any_instance.stub(:bulk).and_return(*resp)
      LogStash::Outputs::Elasticsearch::Protocols::NodeClient
        .any_instance.stub(:bulk).and_return(*resp)
      LogStash::Outputs::Elasticsearch::Protocols::TransportClient
        .any_instance.stub(:bulk).and_return(*resp)
    end

    ["node", "transport", "http"].each do |protocol|
      context "with protocol => #{protocol}" do
        subject do
          require "logstash/outputs/elasticsearch"
          settings = {
            "manage_template" => true,
            "index" => "logstash-2014.11.17",
            "template_overwrite" => true,
            "protocol" => protocol,
            "host" => "localhost",
            "retry_max_items" => 10,
            "retry_max_interval" => 1,
            "max_retries" => max_retries
          }
          next LogStash::Outputs::ElasticSearch.new(settings)
        end

        before :each do
          # Delete all templates first.
          require "elasticsearch"

          # Clean ES of data before we start.
          @es = Elasticsearch::Client.new
          @es.indices.delete_template(:name => "*")
          @es.indices.delete(:index => "*")
          @es.indices.refresh
        end

        it "should return no errors if all bulk actions are successful" do
          mock_actions_with_response({"errors" => false})
          expect(subject).to receive(:submit).with([action1, action2]).once.and_call_original
          subject.register
          subject.receive(event1)
          subject.receive(event2)
          subject.buffer_flush(:final => true)
          sleep(2)
        end

        it "should raise exception and be retried by stud::buffer" do
          call_count = 0
          expect(subject).to receive(:submit).with([action1]).exactly(3).times do
            if (call_count += 1) <= 2
              raise "error first two times"
            else
              {"errors" => false}
            end
          end
          subject.register
          subject.receive(event1)
          subject.buffer_flush(:final => true)
        end

        it "should retry actions with response status of 503" do
          mock_actions_with_response({"errors" => true, "statuses" => [200, 200, 503, 503]},
                                     {"errors" => true, "statuses" => [200, 503]},
                                     {"errors" => false})
          expect(subject).to receive(:submit).with([action1, action1, action1, action2]).ordered.once.and_call_original
          expect(subject).to receive(:submit).with([action1, action2]).ordered.once.and_call_original
          expect(subject).to receive(:submit).with([action2]).ordered.once.and_call_original

          subject.register
          subject.receive(event1)
          subject.receive(event1)
          subject.receive(event1)
          subject.receive(event2)
          subject.buffer_flush(:final => true)
          sleep(3)
        end
        
        it "should retry actions with response status of 429" do
          mock_actions_with_response({"errors" => true, "statuses" => [429]},
                                     {"errors" => false})
          expect(subject).to receive(:submit).with([action1]).twice.and_call_original
          subject.register
          subject.receive(event1)
          subject.buffer_flush(:final => true)
          sleep(3)
        end

        it "should retry an event until max_retries reached" do
          mock_actions_with_response({"errors" => true, "statuses" => [429]},
                                     {"errors" => true, "statuses" => [429]},
                                     {"errors" => true, "statuses" => [429]},
                                     {"errors" => true, "statuses" => [429]},
                                     {"errors" => true, "statuses" => [429]},
                                     {"errors" => true, "statuses" => [429]})
          expect(subject).to receive(:submit).with([action1]).exactly(max_retries).times.and_call_original
          subject.register
          subject.receive(event1)
          subject.buffer_flush(:final => true)
          sleep(3)
        end
      end
    end
  end

  describe "elasticsearch protocol", :elasticsearch => true do
    # ElasticSearch related jars
#LogStash::Environment.load_elasticsearch_jars!
    # Load elasticsearch protocol
    require "logstash/outputs/elasticsearch/protocol"

    describe "elasticsearch node client" do
      # Test ElasticSearch Node Client
      # Reference: http://www.elasticsearch.org/guide/reference/modules/discovery/zen/

      it "should support hosts in both string and array" do
        # Because we defined *hosts* method in NodeClient as private,
        # we use *obj.send :method,[args...]* to call method *hosts*
        client = LogStash::Outputs::Elasticsearch::Protocols::NodeClient.new

        # Node client should support host in string
        # Case 1: default :host in string
        insist { client.send :hosts, :host => "host",:port => 9300 } == "host:9300"
        # Case 2: :port =~ /^\d+_\d+$/
        insist { client.send :hosts, :host => "host",:port => "9300-9302"} == "host:9300,host:9301,host:9302"
        # Case 3: :host =~ /^.+:.+$/
        insist { client.send :hosts, :host => "host:9303",:port => 9300 } == "host:9303"
        # Case 4:  :host =~ /^.+:.+$/ and :port =~ /^\d+_\d+$/
        insist { client.send :hosts, :host => "host:9303",:port => "9300-9302"} == "host:9303"

        # Node client should support host in array
        # Case 5: :host in array with single item
        insist { client.send :hosts, :host => ["host"],:port => 9300 } == ("host:9300")
        # Case 6: :host in array with more than one items
        insist { client.send :hosts, :host => ["host1","host2"],:port => 9300 } == "host1:9300,host2:9300"
        # Case 7: :host in array with more than one items and :port =~ /^\d+_\d+$/
        insist { client.send :hosts, :host => ["host1","host2"],:port => "9300-9302" } == "host1:9300,host1:9301,host1:9302,host2:9300,host2:9301,host2:9302"
        # Case 8: :host in array with more than one items and some :host =~ /^.+:.+$/
        insist { client.send :hosts, :host => ["host1","host2:9303"],:port => 9300 } == "host1:9300,host2:9303"
        # Case 9: :host in array with more than one items, :port =~ /^\d+_\d+$/ and some :host =~ /^.+:.+$/
        insist { client.send :hosts, :host => ["host1","host2:9303"],:port => "9300-9302" } == "host1:9300,host1:9301,host1:9302,host2:9303"
      end
    end
  end

  describe "Authentication option" do
    ["node", "transport"].each do |protocol|
      context "with protocol => #{protocol}" do
        subject do
          require "logstash/outputs/elasticsearch"
          settings = {
            "protocol" => protocol,
            "node_name" => "logstash",
            "cluster" => "elasticsearch",
            "host" => "node01",
            "user" => "test",
            "password" => "test"
          }
          next LogStash::Outputs::ElasticSearch.new(settings)
        end

        it "should fail in register" do
          expect {subject.register}.to raise_error
        end
      end
    end
  end

  describe "SSL option" do
    ["node", "transport"].each do |protocol|
      context "with protocol => #{protocol}" do
        subject do
          require "logstash/outputs/elasticsearch"
          settings = {
            "protocol" => protocol,
            "node_name" => "logstash",
            "cluster" => "elasticsearch",
            "host" => "node01",
            "ssl" => true
          }
          next LogStash::Outputs::ElasticSearch.new(settings)
        end

        it "should fail in register" do
          expect {subject.register}.to raise_error
        end
      end
    end
  end

  describe "send messages to ElasticSearch using HTTPS", :elasticsearch_secure => true do
    subject do
      require "logstash/outputs/elasticsearch"
      settings = {
        "protocol" => "http",
        "node_name" => "logstash",
        "cluster" => "elasticsearch",
        "host" => "node01",
        "user" => "user",
        "password" => "changeme",
        "ssl" => true,
        "cacert" => "/tmp/ca/certs/cacert.pem",
        # or
        #"truststore" => "/tmp/ca/truststore.jks",
        #"truststore_password" => "testeteste"
      }
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    before :each do
      subject.register
    end

    it "sends events to ES" do
      expect {
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
      }.to_not raise_error
    end
  end

  describe "connect using HTTP Authentication", :elasticsearch_secure => true do
    subject do
      require "logstash/outputs/elasticsearch"
      settings = {
        "protocol" => "http",
        "cluster" => "elasticsearch",
        "host" => "node01",
        "user" => "user",
        "password" => "changeme",
      }
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    before :each do
      subject.register
    end

    it "sends events to ES" do
      expect {
        subject.receive(LogStash::Event.new("message" => "sample message here"))
        subject.buffer_flush(:final => true)
      }.to_not raise_error
    end
  end

  describe "transport protocol" do

    context "sniffing => true" do

      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "host" => "node01",
          "protocol" => "transport",
          "sniffing" => true
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should set the sniffing property to true" do
        expect_any_instance_of(LogStash::Outputs::Elasticsearch::Protocols::TransportClient).to receive(:client).and_return(nil)
        subject.register
        client = subject.instance_eval("@current_client")
        settings = client.instance_eval("@settings")

        expect(settings.build.getAsMap["client.transport.sniff"]).to eq("true")
      end
    end

    context "sniffing => false" do

      subject do
        require "logstash/outputs/elasticsearch"
        settings = {
          "host" => "node01",
          "protocol" => "transport",
          "sniffing" => false
        }
        next LogStash::Outputs::ElasticSearch.new(settings)
      end

      it "should set the sniffing property to true" do
        expect_any_instance_of(LogStash::Outputs::Elasticsearch::Protocols::TransportClient).to receive(:client).and_return(nil)
        subject.register
        client = subject.instance_eval("@current_client")
        settings = client.instance_eval("@settings")

        expect(settings.build.getAsMap["client.transport.sniff"]).to eq("false")
      end
    end
  end
end
