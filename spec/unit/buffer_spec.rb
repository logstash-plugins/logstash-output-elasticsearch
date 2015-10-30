require "logstash/outputs/elasticsearch"
require "logstash/outputs/elasticsearch/buffer"

describe LogStash::Outputs::ElasticSearch::Buffer do
  class OperationTarget # Used to track buffer flushesn
    attr_reader :buffer, :buffer_history, :receive_count
    def initialize
      @buffer = nil
      @buffer_history = []
      @receive_count = 0
    end

    def receive(buffer)
      @receive_count += 1
      @buffer_history << buffer.clone
      @buffer = buffer
    end
  end

  let(:logger) { Cabin::Channel.get }
  let(:max_size) { 10 }
  let(:flush_interval) { 2 }
  # Used to track flush count
  let(:operation_target) { OperationTarget.new() }
  let(:operation) { proc {|buffer| operation_target.receive(buffer) } }
  subject(:buffer){ LogStash::Outputs::ElasticSearch::Buffer.new(logger, max_size, flush_interval, &operation) }

  after(:each) do
    buffer.stop
  end

  it "should initialize cleanly" do
    expect(buffer).to be_a(LogStash::Outputs::ElasticSearch::Buffer)
  end

  shared_examples("a buffer with two items inside") do
    it "should add a pushed item to the buffer" do
      buffer.synchronize do |data|
        expect(data).to include(item1)
        expect(data).to include(item2)
      end
    end

    describe "interval flushing" do
      before do
        sleep flush_interval + 1
      end

      it "should flush the buffer after the interval has passed" do
        expect(operation_target.receive_count).to eql(1)
      end

      it "should clear the buffer after a successful flush" do
        expect(operation_target.buffer).to eql([])
      end
    end

    describe "interval flushing a stopped buffer" do
      before do
        buffer.stop
        sleep flush_interval + 1
      end

      it "should not flush if the buffer is stopped" do
        expect(operation_target.receive_count).to eql(0)
      end
    end
  end

  describe "with a buffer push" do
    let(:item1) { "foo" }
    let(:item2) { "bar" }

    describe "a buffer with two items pushed to it separately" do
      before do
        buffer << item1
        buffer << item2
      end

      include_examples("a buffer with two items inside")
    end

    describe "a buffer with two items pushed to it in one operation" do
      before do
        buffer.push_multi([item1, item2])
      end

      include_examples("a buffer with two items inside")
    end
  end

  describe "flushing with an operation that raises an error" do
    class TestError < StandardError; end
    let(:operation) { proc {|buffer| raise TestError, "A test" } }
    let(:item) { double("item") }

    before do
      buffer << item
    end

    it "should raise an exception" do
      expect { buffer.flush }.to raise_error(TestError)
    end

    it "should not clear the buffer" do
      expect do
        buffer.flush rescue TestError
      end.not_to change(buffer, :contents)
    end
  end
end