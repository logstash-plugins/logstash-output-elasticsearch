require_relative "../../../spec/es_spec_helper"

shared_examples_for 'an Elasticsearch instance that does not support index lifecycle management' do
  require "logstash/outputs/elasticsearch"

  let (:ilm_enabled) { false }
  let (:settings) {
    {
        "ilm_enabled" => ilm_enabled,
        "hosts" => "#{get_host_port()}"
    }
  }

  before :each do
    require "elasticsearch"

    # Clean ES of data before we start.
    @es = get_client
    clean(@es)
  end

  after :each do
    clean(@es)
  end

  subject { LogStash::Outputs::ElasticSearch.new(settings) }

  context 'when ilm is enabled in Logstash' do
    let (:ilm_enabled) { true }

    it 'should raise a configuration error' do
      expect do
        begin
          subject.register
          sleep(1)
        ensure
          subject.stop_template_installer
        end
      end.to raise_error(LogStash::ConfigurationError)
    end
  end

  context 'when ilm is disabled in Logstash' do
    it 'should index documents normally' do
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
      expect(indexes_written.count).to eq(1)
    end
  end

end

shared_examples_for 'an ILM enabled Logstash' do

  context 'with a policy with a maximum number of documents' do
    let (:policy) { small_max_doc_policy }
    let (:ilm_policy_name) { "custom-policy"}
    let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}

    it 'should rollover when the policy max docs is reached' do
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

      sleep(6)

      subject.multi_receive([
                                LogStash::Event.new("country" => "uk"),
                                LogStash::Event.new("country" => "fr"),
                                LogStash::Event.new("geoip" => { "location" => [ 0.1, 1.0 ] })
                            ])

      @es.indices.refresh

      # Wait or fail until everything's indexed.
      Stud::try(20.times) do
        r = @es.search
        expect(r["hits"]["total"]).to eq(9)
      end
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written.count).to eq(3)
      expect(indexes_written["#{ilm_write_alias}-000001"]).to eq(3)
      expect(indexes_written["#{ilm_write_alias}-000002"]).to eq(3)
      expect(indexes_written["#{ilm_write_alias}-000003"]).to eq(3)
    end
  end

  context 'with a policy where the maximum number of documents is not reached' do
    let (:policy) { large_max_doc_policy }
    let (:ilm_policy_name) { "custom-policy"}
    let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}

    it 'should ingest into a single index when max docs is not reached' do
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
      expect(indexes_written.count).to eq(1)
      expect(indexes_written["#{ilm_write_alias}-000001"]).to eq(6)
    end
  end
end


if ESHelper.es_version_satisfies?("<= 6.5")
  describe 'Pre-ILM versions of Elasticsearch', :integration => true do
    it_behaves_like 'an Elasticsearch instance that does not support index lifecycle management'
  end
end

if ESHelper.es_version_satisfies?(">= 6.6")
  describe 'OSS Elasticsearch', :distribution => 'oss', :integration => true do
    it_behaves_like 'an Elasticsearch instance that does not support index lifecycle management'
  end

  describe 'Elasticsearch has index lifecycle management enabled', :distribution => 'xpack', :integration => true do
    DEFAULT_INTERVAL = '600s'

    require "logstash/outputs/elasticsearch"
    let (:ilm_write_alias) { "the_write_alias" }
    let (:index) { ilm_write_alias }
    let (:ilm_enabled) { true }

    let (:settings) {
      {
          "index" => index,
          "ilm_enabled" => ilm_enabled,
          "ilm_write_alias" => ilm_write_alias,
          "manage_template" => true,
          "template_name" => ilm_write_alias,
          "template_overwrite" => true,
          "hosts" => "#{get_host_port()}"
      }
    }
    let (:policy) { small_max_doc_policy }

    let (:small_max_doc_policy) {
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

    let (:large_max_doc_policy) {
      {"policy" => {
          "phases"=> {
              "hot" => {
                  "actions" => {
                      "rollover" => {
                          "max_docs" => "1000000"
                      }
                  }
              }
          }
      }}
    }



    subject { LogStash::Outputs::ElasticSearch.new(settings) }

    before :each do
      # Delete all templates first.
      require "elasticsearch"

      # Clean ES of data before we start.
      @es = get_client
      clean(@es)
      # Set the poll interval for lifecycle management to be short so changes get picked up in time.
      set_cluster_settings(@es,  {
          "persistent" => {
          "indices.lifecycle.poll_interval" => "1s"
          }
      })
    end

    after :each do
      # Set poll interval back to default
      set_cluster_settings(@es,  {
          "persistent" => {
              "indices.lifecycle.poll_interval" => DEFAULT_INTERVAL
          }
      })
      clean(@es)
    end


    context 'with ilm enabled' do
      let (:ilm_enabled) { true }

      context 'when using the default policy' do
        it 'should install it if it is not present' do
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
          subject.register
          sleep(1)
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.not_to raise_error
        end
      end


      context 'when not using the default policy' do
        let (:ilm_policy_name) {"new_one"}
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}
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
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
          put_policy(@es,ilm_policy_name, policy)
        end

        it 'should not install the default policy if it is not used' do
          subject.register
          sleep(1)
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
        end
      end

      context 'with the default template' do

        it 'should write the write alias' do
          expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_falsey
          subject.register
          sleep(1)
          expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_truthy
        end

        it_behaves_like 'an ILM enabled Logstash'
      end

      context 'with a custom template' do
        let (:ilm_write_alias) { "custom" }
        let (:index) { ilm_write_alias }
        let (:template_name) { "custom" }
        if ESHelper.es_version_satisfies?(">= 7.0")
          let (:template) { "spec/fixtures/template-with-policy-es7x.json" }
        else
          let (:template) { "spec/fixtures/template-with-policy-es6x.json" }
        end
        let (:ilm_enabled) { true }
        let (:ilm_policy_name) { "custom-policy" }
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name, "template" => template)}

        before :each do
          put_policy(@es,ilm_policy_name, policy)
        end
        it 'should write the write alias' do
          expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_falsey
          subject.register
          sleep(1)
          expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_truthy
        end

        it_behaves_like 'an ILM enabled Logstash'
      end
    end

    context 'with ilm disabled' do
      let (:ilm_enabled) { false }

      it 'should not write the write alias' do
        expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_falsey
        subject.register
        sleep(1)
        expect(@es.indices.exists_alias(index: ilm_write_alias)).to be_falsey
      end

      it 'should not install the default policy' do
        subject.register
        sleep(1)
        expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      end

      context 'with an existing policy that will roll over' do
        let (:policy) { small_max_doc_policy }
        let (:ilm_policy_name) { "3_docs"}
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}

        it 'should index documents normally' do

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
          expect(indexes_written.count).to eq(1)
          expect(indexes_written["#{index}"]).to eq(6)
        end
      end
    end
  end
end