require "spec"
require "../src/sequin_tool/cli"

describe SequinTool::CLI do
  it "prints top-level help" do
    cli = SequinTool::CLI.new
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    cli.run(["--help"], stdout, stderr).should eq(0)
    stdout.to_s.should contain("sequin_tool - unified Crystal CLI skeleton")
    stdout.to_s.should contain("verify:chain")
    stderr.to_s.should eq("")
  end

  it "prints command help" do
    cli = SequinTool::CLI.new
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    cli.run(["help", "wallet:create"], stdout, stderr).should eq(0)
    stdout.to_s.should contain("wallet:create - Create a wallet keypair")
    stdout.to_s.should contain("Implementation target: Phase 5")
    stderr.to_s.should eq("")
  end

  it "returns a clear stub response for a routed command" do
    cli = SequinTool::CLI.new
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    cli.run(["verify:chain"], stdout, stderr).should eq(1)
    stdout.to_s.should eq("")
    stderr.to_s.should contain(%("status":"stub"))
    stderr.to_s.should contain(%("command":"verify:chain"))
  end

  it "returns a structured error for unknown commands" do
    cli = SequinTool::CLI.new
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    cli.run(["nope"], stdout, stderr).should eq(2)
    stderr.to_s.should contain(%("status":"error"))
    stderr.to_s.should contain(%("command":"nope"))
  end
end
