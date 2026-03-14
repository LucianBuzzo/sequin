require "file_utils"
require "spec"
require "json"
require "../src/sequin_tool/cli"

private def with_tmp_repo
  dir = File.join(Dir.tempdir, "sequin-spec-#{Random::Secure.hex(6)}")
  begin
    Dir.mkdir_p(dir)
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

describe SequinTool::CLI do
  it "prints top-level help" do
    cli = SequinTool::CLI.new
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    cli.run(["--help"], stdout, stderr).should eq(0)
    stdout.to_s.should contain("sequin_tool - unified Crystal CLI")
    stdout.to_s.should contain("verify:chain")
    stderr.to_s.should eq("")
  end

  it "runs verify:chain successfully against minimal ledger" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "ledger", "blocks"))
      Dir.mkdir_p(File.join(root, "ledger", "state"))

      File.write(File.join(root, "ledger", "blocks", "000000.json"), {
        "height" => 0,
        "prevHash" => nil,
        "txIds" => [] of String,
        "timestamp" => "2026-03-13T00:00:00Z",
        "proposer" => "genesis",
      }.to_pretty_json + "\n")

      File.write(File.join(root, "ledger", "state", "meta.json"), {
        "chain" => "sequin-github",
        "version" => 1,
        "lastHeight" => 0,
        "lastUpdated" => nil,
      }.to_pretty_json + "\n")

      cli = SequinTool::CLI.new
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      cli.run(["verify:chain"], stdout, stderr, root).should eq(0)
      stdout.to_s.should contain("Chain valid")
      stderr.to_s.should eq("")
    end
  end

  it "applies a pending tx into a new block" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "ledger", "blocks"))
      Dir.mkdir_p(File.join(root, "ledger", "state"))
      Dir.mkdir_p(File.join(root, "tx", "pending"))

      File.write(File.join(root, "ledger", "blocks", "000000.json"), {
        "height" => 0,
        "prevHash" => nil,
        "txIds" => [] of String,
        "timestamp" => "2026-03-13T00:00:00Z",
        "proposer" => "genesis",
      }.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "meta.json"), {
        "chain" => "sequin-github",
        "version" => 1,
        "lastHeight" => 0,
        "lastUpdated" => nil,
      }.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "balances.json"), {"alice" => 100, "bob" => 0}.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "nonces.json"), {"alice" => 0}.to_pretty_json + "\n")

      tx = {
        "id" => "tx-1",
        "from" => "alice",
        "to" => "bob",
        "amount" => 15,
        "nonce" => 1,
        "sigVersion" => 1,
        "memo" => "",
        "createdAt" => "2026-03-14T00:00:00Z",
        "signature" => "stub",
      }
      File.write(File.join(root, "tx", "pending", "2026-03-14T00-00-00Z__tx-1.json"), tx.to_pretty_json + "\n")

      cli = SequinTool::CLI.new
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      cli.run(["ledger:apply-block"], stdout, stderr, root).should eq(0)
      stdout.to_s.should contain("Applied block #1")
      stderr.to_s.should eq("")

      balances = JSON.parse(File.read(File.join(root, "ledger", "state", "balances.json"))).as_h
      balances["alice"].as_i.should eq(85)
      balances["bob"].as_i.should eq(15)
      Dir.children(File.join(root, "tx", "pending")).should be_empty
    end
  end

  it "mints rewards for an epoch" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "ledger", "blocks"))
      Dir.mkdir_p(File.join(root, "ledger", "state"))
      Dir.mkdir_p(File.join(root, "rewards"))
      Dir.mkdir_p(File.join(root, "config"))

      File.write(File.join(root, "ledger", "blocks", "000000.json"), {
        "height" => 0,
        "prevHash" => nil,
        "txIds" => [] of String,
        "timestamp" => "2026-03-13T00:00:00Z",
        "proposer" => "genesis",
      }.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "meta.json"), {
        "chain" => "sequin-github",
        "version" => 1,
        "lastHeight" => 0,
        "lastUpdated" => nil,
      }.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "balances.json"), ({} of String => Int32).to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "reward_epochs.json"), ([] of String).to_pretty_json + "\n")
      File.write(File.join(root, "config", "reward-repos.json"), {
        "dailyEmission" => 10000,
        "maxRewardPerUser" => 3000,
      }.to_pretty_json + "\n")

      reward = {
        "epoch" => "2026-03-13",
        "totals" => {"dailyEmission" => 10000},
        "rewards" => [
          {"github" => "alice", "amount" => 2000},
          {"github" => "bob", "amount" => 1000},
        ],
      }
      File.write(File.join(root, "rewards", "2026-03-13.json"), reward.to_pretty_json + "\n")

      cli = SequinTool::CLI.new
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      cli.run(["rewards:mint", "--date", "2026-03-13"], stdout, stderr, root).should eq(0)
      stdout.to_s.should contain("Minted reward epoch 2026-03-13")
      stderr.to_s.should eq("")

      balances = JSON.parse(File.read(File.join(root, "ledger", "state", "balances.json"))).as_h
      balances["alice"].as_i.should eq(2000)
      balances["bob"].as_i.should eq(1000)

      epochs = JSON.parse(File.read(File.join(root, "ledger", "state", "reward_epochs.json"))).as_a
      epochs.map(&.as_s).should contain("2026-03-13")
    end
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
