require "openssl"
require "json"

class Block
  property previous_block_hash : String
  property block_hash : String
  property data : Hash(String, Int32) | Hash(String, String)

  def initialize(
    timestamp : String,
    @data,
    previous_block_hash : String = ""
  )
    @timestamp = timestamp
    @previous_block_hash = previous_block_hash
    @block_hash = ""
    @block_hash = self.calculate_hash.as(String)
  end

  def calculate_hash()
    new_hash = OpenSSL::Digest.new("SHA256")
    new_hash.update("#{@previous_block_hash}#{@timestamp}#{@data}")
    new_hash.final.hexstring
  end
end

class BlockChain
  getter chain = [] of Block

  def initialize()
    @chain << self.create_genesis_block
  end

  def create_genesis_block()
    Block.new("2021/02/13", { "name" => "Genesis block" }, "0")
  end

  def get_latest_block
    @chain.last
  end

  def add_block(newBlock)
    newBlock.previous_block_hash = self.get_latest_block.block_hash
    newBlock.block_hash = newBlock.calculate_hash
    @chain.push(newBlock)
  end

  def is_chain_valid()
    @chain.each_index { | idx |
      if idx > 0
        current_block = @chain[idx]
        previous_block = @chain[idx - 1]

        if current_block.block_hash != current_block.calculate_hash
          return false
        end

        if current_block.previous_block_hash != previous_block.block_hash
          return false
        end
      end
    }

    return true
  end
end
