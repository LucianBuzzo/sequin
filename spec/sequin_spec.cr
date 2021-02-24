require "spec"
require "secp256k1"
require "../src/sequin"

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
      key_pair = Secp256k1::Keypair.new
      wallet_address = Secp256k1::Util.public_key_compressed_prefix key_pair.public_key
      sequin = BlockChain.new
      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))
      trx = Transaction.new(wallet_address, "address2", 10)
      trx.sign_transaction(key_pair)
      sequin.add_block(Block.new(Time.utc.to_s, [ trx ]))
      sequin.is_chain_valid.should be_true
    end

    it "detects an invalid chain after tampering" do
      key_pair = Secp256k1::Keypair.new
      wallet_address = Secp256k1::Util.public_key_compressed_prefix key_pair.public_key

      sequin = BlockChain.new
      sequin.add_block(Block.new(Time.utc.to_s, [] of Transaction))
      trx = Transaction.new(wallet_address, "address2", 3)
      trx.sign_transaction(key_pair)
      sequin.add_block(Block.new(Time.utc.to_s, [ trx ]))

      sequin.chain[2].transactions[0].amount *= 100
      sequin.chain[2].calculate_hash
      sequin.is_chain_valid.should be_false
    end
  end

  describe "#mine_pending_transactions" do
    it "correctly rewards the miner" do
      key_pair1 = Secp256k1::Keypair.new
      wallet_address1 = Secp256k1::Util.public_key_compressed_prefix key_pair1.public_key
      key_pair2 = Secp256k1::Keypair.new
      wallet_address2 = Secp256k1::Util.public_key_compressed_prefix key_pair2.public_key
      mining_key_pair = Secp256k1::Keypair.new
      mining_address = Secp256k1::Util.public_key_compressed_prefix mining_key_pair.public_key

      sequin = BlockChain.new
      trx1 = Transaction.new(wallet_address1, wallet_address2, 50)
      trx1.sign_transaction(key_pair1)
      trx2 = Transaction.new(wallet_address2, wallet_address1, 100)

      sequin.add_transaction(trx1)

      sequin.mine_pending_transactions(mining_address)

      sequin.get_balance_of_address(mining_address).should eq (0)

      sequin.mine_pending_transactions("mining_address2")

      sequin.get_balance_of_address(mining_address).should eq (sequin.mining_reward)
    end
  end
end
