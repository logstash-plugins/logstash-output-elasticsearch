require_relative "../../../spec/es_spec_helper"


  # describe "Supports Index Lifecycle Management" do #, :integration => true do
  #   let (:ilm_policy_name) {"three_and_done"}
  #   subject! do
  #     require "logstash/outputs/elasticsearch"
  #     settings = {
  #         "index" => "logstash",
  #         "ilm_enabled" => true,
  #         "ilm_policy" => ilm_policy_name,
  #       "manage_template" => true,
  #       "template_overwrite" => true,
  #       "hosts" => "#{get_host_port()}"
  #     }
  #     next LogStash::Outputs::ElasticSearch.new(settings)
  #   end
  #
  #   before :each do
  #     # Delete all templates first.
  #     require "elasticsearch"
  #
  #     # Clean ES of data before we start.
  #     @es = get_client
  #     clean(@es)
  #     @old_cluster_settings = get_cluster_settings(@es)
  #     set_cluster_settings(@es,  {"persistent" => {
  #         "indices.lifecycle.poll_interval" => "1s"}
  #     })
  #
  #
  #     put_policy(@es,ilm_policy_name, {"policy" => {
  #         "phases"=> {
  #             "hot" => {
  #                 "actions" => {
  #                     "rollover" => {
  #                         "max_docs" => "3"
  #                     }
  #                 }
  #             }
  #         }
  #     }})
  #
  #
  #     subject.register
  #
  #     subject.multi_receive([
  #       LogStash::Event.new("message" => "sample message here"),
  #       LogStash::Event.new("somemessage" => { "message" => "sample nested message here" }),
  #       LogStash::Event.new("somevalue" => 100),
  #     ])
  #
  #     sleep(6)
  #
  #     subject.multi_receive([
  #         LogStash::Event.new("country" => "us"),
  #         LogStash::Event.new("country" => "at"),
  #         LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
  #     ])
  #
  #     @es.indices.refresh
  #
  #     # Wait or fail until everything's indexed.
  #     Stud::try(20.times) do
  #       r = @es.search
  #       expect(r["hits"]["total"]).to eq(6)
  #     end
  #   end
  #
  #   after :each do
  #     set_cluster_settings(@es, @old_cluster_settings)
  #     clean(@es)
  #   end
  #
  #   # it 'should have a good template' do
  #   #   puts "the template is #{@es.indices.get_template(name: "logstash")}"
  #   #   expect(@es.indices.get_template(name: "logstash")).to eq("a hat")
  #   # end
  #
  #   it 'should install the default policy if it is not already installed' do
  #
  #   end
  #
  #   it 'should not install the default policy if it is not used' do
  #
  #   end
  #
  #
  #   it 'should rotate the indexes correctly' do
  #     indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
  #       index_written = x['_index']
  #       res[index_written] += 1
  #     end
  #     puts indexes_written
  #     expect(indexes_written['logstash-000001']).to eq(3)
  #     expect(indexes_written['logstash-000002']).to eq(3)
  #   end
  #
  # end


describe "Simple Supports Index Lifecycle Management" do #, :integration => true do
  require "logstash/outputs/elasticsearch"
  let (:ilm_policy_name) {"three_and_done"}
  let (:ilm_write_alias) { "the_write_alias" }
  let (:settings) {
    {
        "index" => ilm_write_alias,
        "ilm_enabled" => true,
        "ilm_policy" => ilm_policy_name,
        "ilm_write_alias" => ilm_write_alias,
        "manage_template" => true,
        "template_overwrite" => true,
        "hosts" => "#{get_host_port()}"
    }
  }
  let (:policy) {
    {"policy" => {
        "phases"=> {
            "hot" => {
                "actions" => {
                    "rollover" => {
                        "max_docs" => "3"
                    }
                }
            }
        }
    }}
  }
  subject do
    # next
    LogStash::Outputs::ElasticSearch.new(settings)
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
  end

  after :each do
    set_cluster_settings(@es, @old_cluster_settings)
    clean(@es)
  end

  # it 'should have a good template' do
  #   puts "the template is #{@es.indices.get_template(name: "logstash")}"
  #   expect(@es.indices.get_template(name: "logstash")).to eq("a hat")
  # end

  # it 'should install the default policy if it is not already installed' do
  #   subject.register
  #
  #   subject.multi_receive([
  #                             LogStash::Event.new("message" => "sample message here"),
  #                             LogStash::Event.new("somemessage" => { "message" => "sample nested message here" }),
  #                             LogStash::Event.new("somevalue" => 100),
  #                         ])
  #
  #   sleep(6)
  #
  #   subject.multi_receive([
  #                             LogStash::Event.new("country" => "us"),
  #                             LogStash::Event.new("country" => "at"),
  #                             LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
  #                         ])
  #
  #   @es.indices.refresh
  #
  #   # Wait or fail until everything's indexed.
  #   Stud::try(20.times) do
  #     r = @es.search
  #     expect(r["hits"]["total"]).to eq(6)
  #   end
  # end

  context 'when using the default policy' do
    let (:ilm_policy_name) { LogStash::Outputs::ElasticSearch::ILMManager::DEFAULT_POLICY }

    it 'should install the default policy if it is used' do
      expect{get_policy(@es, LogStash::Outputs::ElasticSearch::ILMManager::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      subject.register
      sleep(1)
      expect{get_policy(@es, LogStash::Outputs::ElasticSearch::ILMManager::DEFAULT_POLICY)}.not_to raise_error
    end
  end


  context 'when not using the default policy' do
    let (:ilm_policy_name) {"new_one"}
    let (:policy) {{
        "policy" => {
          "phases"=> {
              "hot" => {
                  "actions" => {
                      "rollover" => {
                          "max_docs" => "3"
                      }
                  }
              }
          }
        }}}

    before do
      expect{get_policy(@es, LogStash::Outputs::ElasticSearch::ILMManager::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      put_policy(@es,ilm_policy_name, policy)
    end

    it 'should not install the default policy if it is not used' do
      subject.register
      sleep(1)
      expect{get_policy(@es, LogStash::Outputs::ElasticSearch::ILMManager::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end
  end

  context 'with ilm enabled' do
    it 'should write the write alias' do
      expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_falsey
      subject.register
      sleep(3)
      expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_truthy
    end

    it 'should follow the policy' do
      put_policy(@es,ilm_policy_name, policy)

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
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written["#{ilm_write_alias}-000001"]).to eq(3)
      expect(indexes_written["#{ilm_write_alias}-000002"]).to eq(3)
    end

    it 'should index documents' do
      # put_policy(@es,ilm_policy_name, policy)

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
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written["#{ilm_write_alias}-000001"]).to eq(6)
    end

  end
end