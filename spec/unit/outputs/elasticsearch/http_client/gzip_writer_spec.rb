require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/elasticsearch/http_client"
require "securerandom"
require "stringio"
require "zlib"

describe LogStash::Outputs::ElasticSearch::HttpClient::GzipWriter do
  let(:io) { StringIO.new.tap { |s| s.set_encoding("BINARY") } }
  let(:level) { 1 }
  subject(:writer) { described_class.new(io, level) }

  let(:lines) do
    [
      %Q({"index":{"_index":"logstash"}}\n),
      %Q({"message":"plain ASCII"}\n),
      %Q({"message":"multibyte: é ü 漢字 \u{1F642}"}\n),
      # larger than the 64 KiB buffers
      %Q({"message":"#{SecureRandom.alphanumeric(100_000)}"}\n),
    ]
  end
  let(:data) { lines.join }

  def gunzip(bytes)
    Zlib::GzipReader.new(StringIO.new(bytes)).read
  end

  it "writes gzip that decompresses to the written bytes" do
    lines.each { |line| writer.write(line) }
    writer.close

    expect(gunzip(io.string).b).to eq(data.b)
  end

  it "returns the number of bytes written" do
    expect(writer.write(lines[2])).to eq(lines[2].bytesize)
  end

  it "counts the uncompressed bytes in #pos, also after #close" do
    lines.each { |line| writer.write(line) }
    expect(writer.pos).to eq(data.bytesize)

    writer.close
    expect(writer.pos).to eq(data.bytesize)
  end

  it "closes the IO and returns it on #close, like Zlib::GzipWriter" do
    writer.write(lines[0])

    expect(writer.close).to be(io)
    expect(io).to be_closed
    expect(io.string).to_not be_empty
  end

  it "writes the trailer and keeps the IO open on #finish, like Zlib::GzipWriter" do
    lines.each { |line| writer.write(line) }

    expect(writer.finish).to be(io)
    expect(io).to_not be_closed
    expect(gunzip(io.string).b).to eq(data.b)
    expect(writer.pos).to eq(data.bytesize)
  end

  it "writes compressed data to the IO before #flush once its buffer is full" do
    lines.each { |line| writer.write(line) }

    expect(io.string).to_not be_empty
  end

  it "writes a valid gzip stream when nothing was written" do
    writer.close

    expect(gunzip(io.string)).to eq("")
  end

  it "writes all data written so far to the IO on #flush" do
    lines.first(2).each { |line| writer.write(line) }
    writer.flush

    # 16 + MAX_WBITS: gzip framing; the trailer is not written yet
    inflated = Zlib::Inflate.new(16 + Zlib::MAX_WBITS).inflate(io.string)
    expect(inflated.b).to eq(lines.first(2).join.b)
  end

  it "compresses about as well as Zlib::GzipWriter at the same level" do
    reference_io = StringIO.new.tap { |s| s.set_encoding("BINARY") }
    reference = Zlib::GzipWriter.new(reference_io, level, Zlib::DEFAULT_STRATEGY)
    lines.each { |line| reference.write(line); writer.write(line) }
    reference.close
    writer.close

    expect(io.string.bytesize).to be_within(reference_io.string.bytesize / 20).of(reference_io.string.bytesize)
  end

  context "with level 9" do
    let(:level) { 9 }
    let(:data) { %Q({"message":"repeated text"}\n) * 10_000 }

    it "compresses at least as well as level 1" do
      level_1_io = StringIO.new.tap { |s| s.set_encoding("BINARY") }
      level_1 = described_class.new(level_1_io, 1)
      level_1.write(data)
      level_1.close
      writer.write(data)
      writer.close

      expect(gunzip(io.string)).to eq(data)
      expect(io.string.bytesize).to be <= level_1_io.string.bytesize
    end
  end
end
