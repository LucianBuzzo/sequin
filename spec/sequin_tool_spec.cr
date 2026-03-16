require "base64"
require "file_utils"
require "spec"
require "json"
require "secp256k1"
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
        "dailyEmission" => 3000,
        "maxRewardPerUser" => 3000,
      }.to_pretty_json + "\n")

      reward = {
        "epoch" => "2026-03-13",
        "totals" => {"dailyEmission" => 3000},
        "details" => [
          {"repo" => "owner/repo", "number" => 1, "prKey" => "owner/repo#1", "login" => "alice", "score" => 20.0},
          {"repo" => "owner/repo", "number" => 2, "prKey" => "owner/repo#2", "login" => "bob", "score" => 10.0},
        ],
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
      stdout.to_s.should contain("Minted incremental reward epoch 2026-03-13")
      stderr.to_s.should eq("")

      balances = JSON.parse(File.read(File.join(root, "ledger", "state", "balances.json"))).as_h
      balances["alice"].as_i.should eq(2000)
      balances["bob"].as_i.should eq(1000)

      epochs = JSON.parse(File.read(File.join(root, "ledger", "state", "reward_epochs.json"))).as_a
      epochs.map(&.as_s).should contain("2026-03-13")

      rewarded = JSON.parse(File.read(File.join(root, "ledger", "state", "rewarded_prs.json"))).as_h
      rewarded.has_key?("owner/repo#1").should be_true
      rewarded.has_key?("owner/repo#2").should be_true

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      cli.run(["rewards:mint", "--date", "2026-03-13"], stdout, stderr, root).should eq(0)
      stdout.to_s.should contain("No new reward claims")
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

      alice_key = Secp256k1::Keypair.new
      bob_key = Secp256k1::Keypair.new

      alice_pub = Secp256k1::Util.public_key_compressed_prefix(alice_key.public_key)
      bob_pub = Secp256k1::Util.public_key_compressed_prefix(bob_key.public_key)

      File.write(File.join(root, "wallets", "alice.json"), {
        "github" => "alice",
        "pubkey" => "secp256k1:#{alice_pub}",
        "createdAt" => "2026-03-14T00:00:00Z",
      }.to_pretty_json + "\n")
      File.write(File.join(root, "wallets", "bob.json"), {
        "github" => "bob",
        "pubkey" => "secp256k1:#{bob_pub}",
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

      sig = Secp256k1::Signature.sign(payload, alice_key.private_key)
      sig_b64 = "secp256k1:#{Secp256k1::Util.to_padded_hex_32(sig.r)}:#{Secp256k1::Util.to_padded_hex_32(sig.s)}"

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

  it "creates wallet, computes nonce, and signs tx" do
    with_tmp_repo do |root|
      Dir.mkdir_p(File.join(root, "ledger", "state"))
      File.write(File.join(root, "ledger", "state", "nonces.json"), {"alice" => 2}.to_pretty_json + "\n")

      cli = SequinTool::CLI.new
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      cli.run(["wallet:create", "--github", "alice"], stdout, stderr, root).should eq(0)
      File.exists?(File.join(root, "wallets", "alice.json")).should be_true
      File.exists?(File.join(root, ".sequin", "keys", "alice.key")).should be_true

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      cli.run(["tx:next-nonce", "--user", "alice"], stdout, stderr, root).should eq(0)
      stdout.to_s.strip.should eq("3")

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      cli.run([
        "tx:sign",
        "--from", "alice",
        "--to", "bob",
        "--amount", "5",
        "--nonce", "3",
        "--memo", "hello",
      ], stdout, stderr, root).should eq(0)

      pending = Dir.children(File.join(root, "tx", "pending"))
      pending.size.should eq(1)
      tx = JSON.parse(File.read(File.join(root, "tx", "pending", pending.first))).as_h
      tx["from"].as_s.should eq("alice")
      tx["to"].as_s.should eq("bob")
      tx["amount"].as_i.should eq(5)
      tx["nonce"].as_i.should eq(3)
      tx["signature"].as_s.empty?.should be_false
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
