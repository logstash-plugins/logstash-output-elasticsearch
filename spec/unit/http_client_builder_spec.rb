require "logstash/outputs/elasticsearch"
require "logstash/outputs/elasticsearch/http_client"
require "logstash/outputs/elasticsearch/http_client_builder"

describe LogStash::Outputs::ElasticSearch::HttpClientBuilder do
  describe "auth setup with url encodable passwords" do
    let(:klass) { LogStash::Outputs::ElasticSearch::HttpClientBuilder }
    let(:user) { "foo@bar"}
    let(:password) {"baz@blah" }
    let(:password_secured) do
      secured = double("password")
      allow(secured).to receive(:value).and_return(password)
      secured
    end
    let(:options) { {"user" => user, "password" => password} }
    let(:logger) { mock("logger") }
    let(:auth_setup) { klass.setup_basic_auth(double("logger"), {"user" => user, "password" => password_secured}) }

    it "should return the user verbatim" do
      expect(auth_setup[:user]).to eql(user)
    end

    it "should return the password verbatim" do
      expect(auth_setup[:password]).to eql(password)
    end
  end
end