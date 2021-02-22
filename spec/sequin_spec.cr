require "spec"
require "../src/sequin"

describe Block do
  describe "#new" do
    it "correctly generates a hash" do
      block = Block.new("2021/02/13", { "amount" => 10 })
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

      new_block = Block.new("2021/02/13", { "amount" => 10 })
      sequin.add_block(new_block)

      sequin.get_latest_block.should be(new_block)
    end
  end

  describe "#add_block" do
    it "correctly adds a new block" do
      sequin = BlockChain.new
      genesis_block = sequin.get_latest_block

      sequin.add_block(Block.new("2021/02/13", { "amount" => 10 }))

      last_block = sequin.get_latest_block

      last_block.previous_block_hash.should eq(genesis_block.block_hash)
      sequin.chain.size.should eq(2)
    end

    it "should mine the new block" do
      sequin = BlockChain.new
      genesis_block = sequin.get_latest_block

      sequin.add_block(Block.new("2021/02/13", { "amount" => 10 }))

      last_block = sequin.get_latest_block

      last_block.block_hash[0..sequin.difficulty - 1]
        .should eq ("0" * sequin.difficulty)
    end
  end

  describe "#is_chain_valid" do
    it "correctly validates the chain" do
      sequin = BlockChain.new
      sequin.add_block(Block.new("2021/02/13", { "amount" => 10 }))
      sequin.add_block(Block.new("2021/02/13", { "amount" => 4 }))
      sequin.is_chain_valid.should be_true
    end

    it "detects an invalid chain after tampering" do
      sequin = BlockChain.new
      sequin.add_block(Block.new("2021/02/13", { "amount" => 10 }))
      sequin.add_block(Block.new("2021/02/13", { "amount" => 4 }))
      sequin.chain[1].data = {
        "amount" => 100
      }
      sequin.chain[1].calculate_hash
      sequin.is_chain_valid.should be_false
    end
  end
end
