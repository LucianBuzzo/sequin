require "digest/sha256"
require "file_utils"
require "json"
require "spec"
require "../src/sequin/cli"

private def with_temp_ledger
  root = File.join(Dir.tempdir, "sequin-cli-spec-#{Random.rand(1_000_000)}")
  begin
    FileUtils.mkdir_p(File.join(root, "ledger", "blocks"))
    FileUtils.mkdir_p(File.join(root, "ledger", "state"))
    yield root
  ensure
    FileUtils.rm_rf(root)
  end
end

private def write_json(path : String, contents : String)
  File.write(path, contents)
end

private def write_chain_fixture(root : String)
  blocks_dir = File.join(root, "ledger", "blocks")
  state_dir = File.join(root, "ledger", "state")

  genesis_path = File.join(blocks_dir, "000000.json")
  genesis = %({"height":0,"prevHash":null})
  write_json(genesis_path, genesis)

  genesis_hash = Digest::SHA256.hexdigest(File.read(genesis_path).to_slice)
  block_one_path = File.join(blocks_dir, "000001.json")
  block_one = %({"height":1,"prevHash":"#{genesis_hash}"})
  write_json(block_one_path, block_one)

  write_json(File.join(state_dir, "meta.json"), %({"chain":"sequin-github","version":1,"lastHeight":1,"lastUpdated":"2026-03-14T12:00:00Z"}))
  write_json(File.join(state_dir, "balances.json"), %({"zoe":7,"alice":12,"bob":12.5}))
  write_json(File.join(state_dir, "reward_epochs.json"), %(["2026-03-12","2026-03-13","2026-03-14"]))
end

describe Sequin::Commands::VerifyChain do
  it "matches the JS success output for a valid chain" do
    with_temp_ledger do |root|
      write_chain_fixture(root)
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = Sequin::Commands::VerifyChain.new(stdout, stderr).call(root)

      exit_code.should eq(0)
      stdout.to_s.should eq("✅ Chain valid (2 blocks, tip=1)\n")
      stderr.to_s.should eq("")
    end
  end

  it "fails when block linkage is invalid" do
    with_temp_ledger do |root|
      write_chain_fixture(root)
      block_one_path = File.join(root, "ledger", "blocks", "000001.json")
      write_json(block_one_path, %({"height":1,"prevHash":"bogus"}))

      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = Sequin::Commands::VerifyChain.new(stdout, stderr).call(root)

      exit_code.should eq(1)
      stdout.to_s.should eq("")
      stderr.to_s.should contain("❌ 000001.json: prevHash mismatch")
    end
  end
end

describe Sequin::Commands::LedgerSummary do
  it "prints the same summary structure as the JS script" do
    with_temp_ledger do |root|
      write_chain_fixture(root)
      stdout = IO::Memory.new

      exit_code = Sequin::Commands::LedgerSummary.new(stdout).call(
        Sequin::Commands::LedgerSummary::Options.new(top: 2, epochs: 2),
        root
      )

      exit_code.should eq(0)
      stdout.to_s.should eq <<-TEXT
Chain: sequin-github v1 | tip=1
Last updated: 2026-03-14T12:00:00Z

Top 2 balances:
- bob: 12.5
- alice: 12

Recent minted reward epochs (2/3):
- 2026-03-14
- 2026-03-13

TEXT
    end
  end
end

describe Sequin::CLI do
  it "routes verify:chain through the CLI entrypoint" do
    with_temp_ledger do |root|
      write_chain_fixture(root)
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      exit_code = Sequin::CLI.new(stdout, stderr).run(["verify:chain"], root)

      exit_code.should eq(0)
      stdout.to_s.should eq("✅ Chain valid (2 blocks, tip=1)\n")
      stderr.to_s.should eq("")
    end
  end
end
