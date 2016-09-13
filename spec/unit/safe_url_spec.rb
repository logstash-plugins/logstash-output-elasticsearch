require "logstash/outputs/elasticsearch/safe_url"
require "uri"

describe ::LogStash::Outputs::ElasticSearch::SafeURL do
  context "#without_credentials" do
    subject { described_class.without_credentials(url) }

    shared_examples_for "returning a new object" do
      it "should return a new url object" do
        expect(subject.object_id).not_to be == url.object_id
      end
    end

    context "when given a url without credentials" do
      let(:url) { URI.parse("https://example.com/") }

      it_behaves_like "returning a new object"

      it "should return the same url" do
        expect(subject).to be == url
      end
    end

    context "when url contains credentials" do
      let(:url) { URI.parse("https://user:pass@example.com/") }

      it_behaves_like "returning a new object"
      
      it "should hide the user" do
        expect(subject.user).to be == "~hidden~"
      end

      it "should hide the password" do
        expect(subject.user).to be == "~hidden~"
      end

      context "#to_s" do
        it "should not contain credentials" do
          expect(subject.to_s).to be == "https://~hidden~:~hidden~@example.com/"
        end
      end
    end
  end
end
