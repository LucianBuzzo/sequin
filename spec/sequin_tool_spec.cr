require "base64"
require "file_utils"
require "spec"
require "json"
require "../src/sequin_tool/cli"
require "../src/sequin_tool/commands/score_epoch"

private def with_tmp_repo
  dir = File.join(Dir.tempdir, "sequin-spec-#{Random::Secure.hex(6)}")
  begin
    Dir.mkdir_p(dir)
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

private class FakeScoreClient
  include SequinTool::Commands::ScoreEpoch::Client

  def initialize(@repo_numbers : Hash(String, Array(Int32)), @pulls : Hash(String, JSON::Any))
  end

  def merged_pr_numbers(repo : String, date : String) : Array(Int32)
    @repo_numbers[repo]? || [] of Int32
  end

  def load_pr(repo : String, number : Int32) : JSON::Any
    @pulls["#{repo}##{number}"]
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

  it "scores epoch rewards from github activity" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "config"))
      Dir.mkdir_p(File.join(root, "rewards"))

      File.write(File.join(root, "config", "reward-repos.json"), {
        "repos" => ["owner/repo"],
        "excludeLogins" => ["dependabot[bot]"],
        "dailyEmission" => 10000,
        "maxPRsPerUser" => 5,
        "maxScorePerUser" => 120,
        "abortIfNoMergedPRsOnWeekday" => false,
      }.to_pretty_json + "\n")

      pr = {
        "number" => 1,
        "title" => "Add feature",
        "user" => {"login" => "alice"},
        "additions" => 40,
        "deletions" => 5,
        "changed_files" => 3,
        "draft" => false,
        "merged_by" => {"login" => "reviewer"},
      }

      client = FakeScoreClient.new(
        {"owner/repo" => [1]},
        {"owner/repo#1" => JSON.parse(pr.to_json)}
      )

      cmd = SequinTool::Commands::ScoreEpoch.new(IO::Memory.new, IO::Memory.new, client)
      cmd.call("2026-03-13", root).should eq(0)

      out = JSON.parse(File.read(File.join(root, "rewards", "2026-03-13.json"))).as_h
      out["epoch"].as_s.should eq("2026-03-13")
      out["rewards"].as_a.size.should eq(1)
      out["rewards"].as_a[0].as_h["github"].as_s.should eq("alice")
      out["totals"].as_h["mergedPrCount"].as_i.should eq(1)
    end
  end

  it "validates pending tx signatures with verify:tx" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "ledger", "state"))
      Dir.mkdir_p(File.join(root, "wallets"))
      Dir.mkdir_p(File.join(root, "tx", "pending"))

      File.write(File.join(root, "ledger", "state", "balances.json"), {"alice" => 100, "bob" => 0}.to_pretty_json + "\n")
      File.write(File.join(root, "ledger", "state", "nonces.json"), {"alice" => 0}.to_pretty_json + "\n")

      key_path = File.join(root, "alice.key.pem")
      pub_der = File.join(root, "alice.pub.der")
      status = Process.run("openssl", ["genpkey", "-algorithm", "Ed25519", "-out", key_path])
      status.success?.should be_true
      status = Process.run("openssl", ["pkey", "-in", key_path, "-pubout", "-outform", "DER", "-out", pub_der])
      status.success?.should be_true

      pub_bytes = File.read(pub_der).to_slice
      pub_bytes.size.should be >= 32
      raw_pub = pub_bytes[pub_bytes.size - 32, 32]
      pub_b64 = Base64.strict_encode(raw_pub)

      bob_key_path = File.join(root, "bob.key.pem")
      bob_pub_der = File.join(root, "bob.pub.der")
      status = Process.run("openssl", ["genpkey", "-algorithm", "Ed25519", "-out", bob_key_path])
      status.success?.should be_true
      status = Process.run("openssl", ["pkey", "-in", bob_key_path, "-pubout", "-outform", "DER", "-out", bob_pub_der])
      status.success?.should be_true
      bob_pub_bytes = File.read(bob_pub_der).to_slice
      bob_pub_bytes.size.should be >= 32
      bob_pub_b64 = Base64.strict_encode(bob_pub_bytes[bob_pub_bytes.size - 32, 32])

      File.write(File.join(root, "wallets", "alice.json"), {
        "github" => "alice",
        "pubkey" => "ed25519:#{pub_b64}",
        "createdAt" => "2026-03-14T00:00:00Z",
      }.to_pretty_json + "\n")
      File.write(File.join(root, "wallets", "bob.json"), {
        "github" => "bob",
        "pubkey" => "ed25519:#{bob_pub_b64}",
        "createdAt" => "2026-03-14T00:00:00Z",
      }.to_pretty_json + "\n")

      payload = JSON.build do |json|
        json.object do
          json.field "id", "tx-1"
          json.field "from", "alice"
          json.field "to", "bob"
          json.field "amount", 10
          json.field "nonce", 1
          json.field "sigVersion", 1
          json.field "memo", ""
          json.field "createdAt", "2026-03-14T00:00:00Z"
        end
      end

      msg_path = File.join(root, "txmsg.json")
      sig_path = File.join(root, "txsig.bin")
      File.write(msg_path, payload)
      status = Process.run("openssl", ["pkeyutl", "-sign", "-inkey", key_path, "-rawin", "-in", msg_path, "-out", sig_path])
      status.success?.should be_true
      sig_b64 = Base64.strict_encode(File.read(sig_path).to_slice)

      tx = {
        "id" => "tx-1",
        "from" => "alice",
        "to" => "bob",
        "amount" => 10,
        "nonce" => 1,
        "sigVersion" => 1,
        "memo" => "",
        "createdAt" => "2026-03-14T00:00:00Z",
        "signature" => sig_b64,
      }
      File.write(File.join(root, "tx", "pending", "2026-03-14T00-00-00Z__tx-1.json"), tx.to_pretty_json + "\n")

      cli = SequinTool::CLI.new
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      cli.run(["verify:tx"], stdout, stderr, root).should eq(0)
      stdout.to_s.should contain("Validated 1 pending transaction")
      stderr.to_s.should eq("")
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
