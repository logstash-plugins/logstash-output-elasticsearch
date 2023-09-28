require_relative "../../../spec/es_spec_helper"
require "childprocess"

describe "startup", :integration => true do
  it "exits when post register raises error" do
    host = get_host_port()
    ls_home = "/usr/share/logstash"

    out = Tempfile.new("content")
    out.sync = true

    args = []
    args << "-e"
    args << "input{ stdin{} } output{ elasticsearch { hosts => '#{host}' template => '#{ls_home}'} }"

    process = ChildProcess.build("#{ls_home}/bin/logstash", *args)
    process.io.stdout = process.io.stderr = out
    process.start
    process.poll_for_exit(60)
    out.rewind

    log = out.read
    puts log

    expect(process.exit_code).to eq(0)
    expect(log).to match /Failed to bootstrap. Pipeline "main" is going to shut down/
  end
end
