require "spec"
require "../src/blockchain"

describe Block do
  describe "#new" do
    it "correctly generates a hash" do
      block = Block.new(Time.utc.to_s, [] of Transaction)
      block.block_hash.should be_a(String)
    end
  end
end

describe Block do
  describe "#new" do
    it "correctly generates a hash" do
      block = Block.new(Time.utc.to_s, [] of Transaction)
      block.block_hash.should be_a(String)
    end
  end
end
describe Block do
  describe "#new" do
    it "correctly generates a hash" do
      block = Block.new(Time.utc.to_s, [] of Transaction)
      block.block_hash.should be_a(String)
    end
  end
end
describe BlockChain do
  describe "#new" do
    it "correctly creates a genesis block" do
      sequin = BlockChain.new
      genesis_block = sequin.chain.last
      genesis_block.should be_a(Block)
      sequin.chain.size.should eq(1)
    end
  end

  describe "#get_latest_block" do
    it "returns the latest block" do
      sequin = BlockChain.new
      wallet = Wallet.new
      genesis_block = sequin.chain.last

      sequin.get_latest_block.should be(genesis_block)

      sequin.mine_pending_transactions(wallet.address)

      sequin.get_latest_block.should_not be(genesis_block)
    end
  end

  describe "#is_chain_valid" do
    it "correctly validates the chain" do
      wallet = Wallet.new
      sequin = BlockChain.new
      sequin.mine_pending_transactions(wallet.address)
      sequin.mine_pending_transactions(wallet.address)
      trx = wallet.create_transaction("address2", 10.00)
      sequin.add_transaction(trx)
      sequin.mine_pending_transactions(wallet.address)
      sequin.is_chain_valid.should be_true
    end

    it "detects an invalid chain after tampering" do
      wallet = Wallet.new

      sequin = BlockChain.new
      sequin.mine_pending_transactions(wallet.address)
      sequin.mine_pending_transactions(wallet.address)
      trx = wallet.create_transaction("address2", 3.00)
      sequin.add_transaction(trx)
      sequin.mine_pending_transactions(wallet.address)

      sequin.chain[2].transactions[0].amount *= 100
      sequin.chain[2].calculate_hash
      sequin.is_chain_valid.should be_false
    end
  end

  describe "#mine_pending_transactions" do
    it "correctly rewards the miner" do
      wallet_1 = Wallet.new
      wallet_2 = Wallet.new
      mining_wallet = Wallet.new

      sequin = BlockChain.new

      sequin.mine_pending_transactions(mining_wallet.address)

      sequin.get_balance_of_address(mining_wallet.address).should eq (0)

      sequin.mine_pending_transactions("mining_address2")

      sequin.get_balance_of_address(mining_wallet.address).should eq (sequin.mining_reward)
    end
  end

  describe "#add_transaction" do
    it "Raises an error if there are insufficient funds" do
      wallet_1 = Wallet.new
      wallet_2 = Wallet.new

      sequin = BlockChain.new
      trx = wallet_1.create_transaction(wallet_2.address, 100.00)

      expect_raises(SequinInsufficientFundsException) do
        sequin.add_transaction(trx)
      end
    end
  end
end
