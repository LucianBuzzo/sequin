require "spec"
require "secp256k1"
require "../src/sequin"
require "../src/wallet"

describe Wallet do
  describe "#new" do
    it "correctly generates a hash" do
      wallet = Wallet.new
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
      genesis_block = sequin.chain.last

      sequin.get_latest_block.should be(genesis_block)

      new_block = Block.new(Time.utc.to_s, [] of Transaction)
      sequin.add_block(new_block)

      sequin.get_latest_block.should be(new_block)
    end
  end

  describe "#add_block" do
    it "correctly adds a new block" do
      sequin = BlockChain.new
      genesis_block = sequin.get_latest_block

      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))

      last_block = sequin.get_latest_block

      last_block.previous_block_hash.should eq(genesis_block.block_hash)
      sequin.chain.size.should eq(2)
    end

    it "should mine the new block" do
      sequin = BlockChain.new
      genesis_block = sequin.get_latest_block

      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))

      last_block = sequin.get_latest_block

      last_block.block_hash[0..sequin.difficulty - 1]
        .should eq ("0" * sequin.difficulty)
    end
  end

  describe "#is_chain_valid" do
    it "correctly validates the chain" do
      wallet = Wallet.new
      sequin = BlockChain.new
      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))
      trx = wallet.create_transaction("address2", 10)
      sequin.add_block(Block.new(Time.utc.to_s, [ trx ]))
      sequin.is_chain_valid.should be_true
    end

    it "detects an invalid chain after tampering" do
      wallet = Wallet.new

      sequin = BlockChain.new
      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))
      trx = wallet.create_transaction("address2", 3)
      sequin.add_block(Block.new(Time.utc.to_s, [ trx ]))

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
      trx_1 = wallet_1.create_transaction(wallet_2.address, 0)
      trx_2 = wallet_2.create_transaction(wallet_1.address, 0)

      sequin.add_transaction(trx_1)

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
      trx = wallet_1.create_transaction(wallet_2.address, 100)

      expect_raises(SequinInsufficientFundsException) do
        sequin.add_transaction(trx)
      end
    end
  end
end
