require_relative "../../../spec/es_spec_helper"

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
        expect(r).to have_hits(9)
      end
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written.count).to eq(3)
      expect(indexes_written["#{expected_index}-#{todays_date}-000001"]).to eq(3)
      expect(indexes_written["#{expected_index}-#{todays_date}-000002"]).to eq(3)
      expect(indexes_written["#{expected_index}-#{todays_date}-000003"]).to eq(3)
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
        expect(r).to have_hits(6)
      end
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written.count).to eq(1)
      expect(indexes_written["#{expected_index}-#{todays_date}-000001"]).to eq(6)
    end
  end
end

shared_examples_for 'an ILM disabled Logstash' do
  it 'should not create a rollover alias' do
    expect(@es.get_alias).to be_empty
    subject.register
    sleep(1)
    expect(@es.get_alias).to be_empty
  end

  it 'should not install the default policy' do
    subject.register
    sleep(1)
    expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
  end

  it 'should not write the ILM settings into the template' do
    subject.register
    sleep(1)
    expect(@es.indices.get_template(name: "logstash")["logstash"]).to have_index_pattern("logstash-*")
    if ESHelper.es_version_satisfies?(">= 2")
      expect(@es.indices.get_template(name: "logstash")["logstash"]["settings"]['index']['lifecycle']).to be_nil
    end
  end

  context 'with an existing policy that will roll over' do
    let (:policy) { small_max_doc_policy }
    let (:ilm_policy_name) { "3_docs"}
    let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}

    it 'should not roll over indices' do
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
        expect(r).to have_hits(6)
      end
      indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
        index_written = x['_index']
        res[index_written] += 1
      end
      expect(indexes_written.count).to eq(1)
      expect(indexes_written.values.first).to eq(6)
    end
  end

  context 'with a custom template name' do
    let (:template_name) { "custom_template_name" }
    let (:settings) { super.merge('template_name' => template_name)}

    it 'should not write the ILM settings into the template' do
      subject.register
      sleep(1)

      expect(@es.indices.get_template(name: template_name)[template_name]).to have_index_pattern("logstash-*")
      if ESHelper.es_version_satisfies?(">= 2")
        expect(@es.indices.get_template(name: template_name)[template_name]["settings"]['index']['lifecycle']).to be_nil
      end
    end
  end
end

shared_examples_for 'an Elasticsearch instance that does not support index lifecycle management' do
  require "logstash/outputs/elasticsearch"

  let (:ilm_enabled) { false }
  let (:settings) {
    {
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
    let (:settings) { super.merge!({ 'ilm_enabled' => true }) }

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
    let (:settings) { super.merge!({ 'ilm_enabled' => false }) }

    it_behaves_like 'an ILM disabled Logstash'
  end

  context 'when ilm is set to auto in Logstash' do
    let (:settings) { super.merge!({ 'ilm_enabled' => 'auto' }) }

    it_behaves_like 'an ILM disabled Logstash'
  end

  context 'when ilm is not set in Logstash' do
    it_behaves_like 'an ILM disabled Logstash'
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

    let (:ilm_enabled) { true }

    let (:settings) {
      {
          "ilm_enabled" => ilm_enabled,
          "hosts" => "#{get_host_port()}"
      }
    }
    let (:small_max_doc_policy) { max_docs_policy(3) }
    let (:large_max_doc_policy) { max_docs_policy(1000000) }
    let (:expected_index) { LogStash::Outputs::ElasticSearch::DEFAULT_ROLLOVER_ALIAS }

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
        context 'with a custom pattern' do
          let (:settings) { super.merge("ilm_pattern" => "000001")}
          it 'should create a rollover alias' do
            expect(@es.indices.exists_alias(index: "logstash")).to be_falsey
            subject.register
            sleep(1)
            expect(@es.indices.exists_alias(index: "logstash")).to be_truthy
            expect(@es.get_alias(name: "logstash")).to include("logstash-000001")
          end
        end

        it 'should install it if it is not present' do
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
          subject.register
          sleep(1)
          expect{get_policy(@es, LogStash::Outputs::ElasticSearch::DEFAULT_POLICY)}.not_to raise_error
        end

        it 'should create the default rollover alias' do
          expect(@es.indices.exists_alias(index: "logstash")).to be_falsey
          subject.register
          sleep(1)
          expect(@es.indices.exists_alias(index: "logstash")).to be_truthy
          expect(@es.get_alias(name: "logstash")).to include("logstash-#{todays_date}-000001")
        end

        it 'should ingest into a single index' do
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
            expect(r).to have_hits(6)
          end
          indexes_written = @es.search['hits']['hits'].each_with_object(Hash.new(0)) do |x, res|
            index_written = x['_index']
            res[index_written] += 1
          end

          expect(indexes_written.count).to eq(1)
          expect(indexes_written["logstash-#{todays_date}-000001"]).to eq(6)
        end
      end

      context 'when not using the default policy' do
        let (:ilm_policy_name) {"new_one"}
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}
        let (:policy) { small_max_doc_policy }

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

      context 'when using a time based policy' do
        let (:ilm_policy_name) {"new_one"}
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name)}
        let (:policy) { max_age_policy("1d") }

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
        it 'should create the rollover alias' do
          expect(@es.indices.exists_alias(index: expected_index)).to be_falsey
          subject.register
          sleep(1)
          expect(@es.indices.exists_alias(index: expected_index)).to be_truthy
          expect(@es.get_alias(name: expected_index)).to include("#{expected_index}-#{todays_date}-000001")
        end

        it 'should write the ILM settings into the template' do
          subject.register
          sleep(1)
          expect(@es.indices.get_template(name: "logstash")["logstash"]).to have_index_pattern("logstash-*")
          expect(@es.indices.get_template(name: "logstash")["logstash"]["settings"]['index']['lifecycle']['name']).to eq("logstash-policy")
          expect(@es.indices.get_template(name: "logstash")["logstash"]["settings"]['index']['lifecycle']['rollover_alias']).to eq("logstash")
        end

        it_behaves_like 'an ILM enabled Logstash'
      end

      context 'with a set index and a custom index pattern' do
        if ESHelper.es_version_satisfies?(">= 7.0")
          let (:template) { "spec/fixtures/template-with-policy-es7x.json" }
        else
          let (:template) { "spec/fixtures/template-with-policy-es6x.json" }
        end

        let (:settings) { super.merge("template" => template,
                                      "index" => "overwrite-4")}

        it 'should not overwrite the index patterns' do
          subject.register
          sleep(1)
          expect(@es.indices.get_template(name: "logstash")["logstash"]).to have_index_pattern("overwrite-*")
        end
      end


      context 'with a custom template' do
        let (:ilm_rollover_alias) { "the_cat_in_the_hat" }
        let (:index) { ilm_rollover_alias }
        let(:expected_index) { index }
        let (:settings) { super.merge("ilm_policy" => ilm_policy_name,
                                      "template" => template,
                                      "ilm_rollover_alias" => ilm_rollover_alias)}


        if ESHelper.es_version_satisfies?(">= 7.0")
          let (:template) { "spec/fixtures/template-with-policy-es7x.json" }
        else
          let (:template) { "spec/fixtures/template-with-policy-es6x.json" }
        end
        let (:ilm_enabled) { true }
        let (:ilm_policy_name) { "custom-policy" }
        let (:policy) { small_max_doc_policy }

        before :each do
          put_policy(@es,ilm_policy_name, policy)
        end

        it_behaves_like 'an ILM enabled Logstash'

        it 'should create the rollover alias' do
          expect(@es.indices.exists_alias(index: ilm_rollover_alias)).to be_falsey
          subject.register
          sleep(1)
          expect(@es.indices.exists_alias(index: ilm_rollover_alias)).to be_truthy
          expect(@es.get_alias(name: ilm_rollover_alias)).to include("#{ilm_rollover_alias}-#{todays_date}-000001")
        end

        context 'when the custom rollover alias already exists' do
          it 'should ignore the already exists error' do
            expect(@es.indices.exists_alias(index: ilm_rollover_alias)).to be_falsey
            put_alias(@es, "#{ilm_rollover_alias}-#{todays_date}-000001", ilm_rollover_alias)
            expect(@es.indices.exists_alias(index: ilm_rollover_alias)).to be_truthy
            subject.register
            sleep(1)
            expect(@es.get_alias(name: ilm_rollover_alias)).to include("#{ilm_rollover_alias}-#{todays_date}-000001")
          end

        end

        it 'should write the ILM settings into the template' do
          subject.register
          sleep(1)
          expect(@es.indices.get_template(name: ilm_rollover_alias)[ilm_rollover_alias]).to have_index_pattern("#{ilm_rollover_alias}-*")
          expect(@es.indices.get_template(name: ilm_rollover_alias)[ilm_rollover_alias]["settings"]['index']['lifecycle']['name']).to eq(ilm_policy_name)
          expect(@es.indices.get_template(name: ilm_rollover_alias)[ilm_rollover_alias]["settings"]['index']['lifecycle']['rollover_alias']).to eq(ilm_rollover_alias)
        end

        context 'with a different template_name' do
          let (:template_name) { "custom_template_name" }
          let (:settings) { super.merge('template_name' => template_name)}

          it_behaves_like 'an ILM enabled Logstash'

          it 'should write the ILM settings into the template' do
            subject.register
            sleep(1)
            expect(@es.indices.get_template(name: template_name)[template_name]).to have_index_pattern("#{ilm_rollover_alias}-*")
            expect(@es.indices.get_template(name: template_name)[template_name]["settings"]['index']['lifecycle']['name']).to eq(ilm_policy_name)
            expect(@es.indices.get_template(name: template_name)[template_name]["settings"]['index']['lifecycle']['rollover_alias']).to eq(ilm_rollover_alias)
          end
        end

      end
    end

    context 'when ilm_enabled is set to "auto"' do
      let (:ilm_enabled) { 'auto' }

      if ESHelper.es_version_satisfies?(">=7.0")
        context 'when Elasticsearch is version 7 or above' do
          it_behaves_like 'an ILM enabled Logstash'
        end
      end

      if ESHelper.es_version_satisfies?('< 7.0')
        context 'when Elasticsearch is version 7 or below' do
          it_behaves_like 'an ILM disabled Logstash'
        end
      end
    end

    context 'when ilm_enabled is the default' do
      let (:settings) { super.tap{|x|x.delete('ilm_enabled')}}

      if ESHelper.es_version_satisfies?(">=7.0")
        context 'when Elasticsearch is version 7 or above' do
          it_behaves_like 'an ILM enabled Logstash'
        end
      end

      if ESHelper.es_version_satisfies?('< 7.0')
        context 'when Elasticsearch is version 7 or below' do
          it_behaves_like 'an ILM disabled Logstash'
        end
      end
    end

    context 'with ilm disabled' do
      let (:settings) { super.merge('ilm_enabled' => false )}

      it_behaves_like 'an ILM disabled Logstash'
    end

    context 'with ilm disabled using a string' do
      let (:settings) { super.merge('ilm_enabled' => 'false' )}

      it_behaves_like 'an ILM disabled Logstash'
    end

  end
end