require_relative "../../../spec/es_spec_helper"

if ESHelper.es_version_satisfies?(">= 2")
  describe "Update actions without scripts", :integration => true do
    require "logstash/outputs/elasticsearch"

    def get_es_output( options={} )
      settings = {
        "manage_template" => true,
        "index" => "logstash-update",
        "template_overwrite" => true,
        "hosts" => get_host_port(),
        "action" => "update"
      }
      LogStash::Outputs::ElasticSearch.new(settings.merge!(options))
    end

    before :each do
      @es = get_client
      # Delete all templates first.
      # Clean ES of data before we start.
      @es.indices.delete_template(:name => "*")
      # This can fail if there are no indexes, ignore failure.
      @es.indices.delete(:index => "*") rescue nil
      @es.index(
        :index => 'logstash-update',
        :type => 'doc',
        :id => "123",
        :body => { :message => 'Test', :counter => 1 }
      )
      @es.indices.refresh
    end

    it "should fail without a document_id" do
      subject = get_es_output
      expect { subject.register }.to raise_error(LogStash::ConfigurationError)
    end

    context "when update only" do
      it "should not create new document" do
        subject = get_es_output({ 'document_id' => "456" } )
        subject.register
        subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
        expect {@es.get(:index => 'logstash-update', :type => 'doc', :id => "456", :refresh => true)}.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      end

      it "should update existing document" do
        subject = get_es_output({ 'document_id' => "123" })
        subject.register
        subject.multi_receive([LogStash::Event.new("message" => "updated message here")])
        r = @es.get(:index => 'logstash-update', :type => 'doc', :id => "123", :refresh => true)
        expect(r["_source"]["message"]).to eq('updated message here')
      end

      # The es ruby client treats the data field differently. Make sure this doesn't
      # raise an exception
      it "should update an existing document that has a 'data' field" do
        subject = get_es_output({ 'document_id' => "123" })
        subject.register
        subject.multi_receive([LogStash::Event.new("data" => "updated message here", "message" => "foo")])
        r = @es.get(:index => 'logstash-update', :type => 'doc', :id => "123", :refresh => true)
        expect(r["_source"]["data"]).to eq('updated message here')
        expect(r["_source"]["message"]).to eq('foo')
      end

      it "should allow default (internal) version" do
        subject = get_es_output({ 'document_id' => "123", "version" => "99" })
        subject.register
      end

      it "should allow internal version" do
        subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "internal" })
        subject.register
      end

      it "should not allow external version" do
        subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external" })
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end

      it "should not allow external_gt version" do
        subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external_gt" })
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end

      it "should not allow external_gte version" do
        subject = get_es_output({ 'document_id' => "123", "version" => "99", "version_type" => "external_gte" })
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end

    end

    context "when update with upsert" do
      it "should create new documents with provided upsert" do
        subject = get_es_output({ 'document_id' => "456", 'upsert' => '{"message": "upsert message"}' })
        subject.register
        subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
        r = @es.get(:index => 'logstash-update', :type => 'doc', :id => "456", :refresh => true)
        expect(r["_source"]["message"]).to eq('upsert message')
      end

      it "should create new documents with event/doc as upsert" do
        subject = get_es_output({ 'document_id' => "456", 'doc_as_upsert' => true })
        subject.register
        subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
        r = @es.get(:index => 'logstash-update', :type => 'doc', :id => "456", :refresh => true)
        expect(r["_source"]["message"]).to eq('sample message here')
      end

      it "should fail on documents with event/doc as upsert at external version" do
        subject = get_es_output({ 'document_id' => "456", 'doc_as_upsert' => true, 'version' => 999, "version_type" => "external" })
        expect { subject.register }.to raise_error(LogStash::ConfigurationError)
      end
    end
  end
end
