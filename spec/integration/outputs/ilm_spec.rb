require_relative "../../../spec/es_spec_helper"


# if ESHelper.supports_ilm?(get_client)
# if ESHelper.es_version_satisfies?(">= 5")
  describe "Supports Index Lifecycle Management" do #, :integration => true do
    let (:ilm_policy_name) {"three_and_done"}
    subject! do
      require "logstash/outputs/elasticsearch"
      settings = {
          "index" => "logstash",
          "ilm_enabled" => true,
          "ilm_policy" => ilm_policy_name,
        "manage_template" => true,
        "template_overwrite" => true,
        "hosts" => "#{get_host_port()}"
      }
      next LogStash::Outputs::ElasticSearch.new(settings)
    end

    before :each do
      # Delete all templates first.
      require "elasticsearch"

      # Clean ES of data before we start.
      @es = get_client
      clean(@es)
      @old_cluster_settings = get_cluster_settings(@es)
      set_cluster_settings(@es,  {"persistent" => {
          "indices.lifecycle.poll_interval" => "1s"}
      })


      put_policy(@es,ilm_policy_name, {"policy" => {
          "phases"=> {
              "hot" => {
                  "actions" => {
                      "rollover" => {
                          "max_docs" => "3"
                      }
                  }
              }
          }
      }})


      subject.register

      subject.multi_receive([
        LogStash::Event.new("message" => "sample message here"),
        LogStash::Event.new("somemessage" => { "message" => "sample nested message here" }),
        LogStash::Event.new("somevalue" => 100),
      ])

      sleep(6)

      subject.multi_receive([
          LogStash::Event.new("country" => "us"),
          LogStash::Event.new("country" => "at"),
          LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
      ])

      @es.indices.refresh

      # Wait or fail until everything's indexed.
      Stud::try(20.times) do
        r = @es.search
        expect(r["hits"]["total"]).to eq(6)
      end
    end

    after :each do
      set_cluster_settings(@es, @old_cluster_settings)
    end

    # it 'should have a good template' do
    #   puts "the template is #{@es.indices.get_template(name: "logstash")}"
    #   expect(@es.indices.get_template(name: "logstash")).to eq("a hat")
    # end

    it 'should rotate the indexes correctly' do
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      puts indexes_written
      expect(indexes_written['logstash-000001']).to eq(3)
      expect(indexes_written['logstash-000002']).to eq(3)
    end

  end
