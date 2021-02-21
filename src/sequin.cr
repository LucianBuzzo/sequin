require "openssl"
require "json"

class Block
  property previous_block_hash : String
  property block_hash : String

  def initialize(
    timestamp : String,
    data : Hash(String, Int32) | Hash(String, String),
    previous_block_hash : String = ""
  )
    @timestamp = timestamp
    @data = data
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
end

sequin = BlockChain.new
sequin.add_block(Block.new("2021/02/13", { "amount" => 10 }))

puts sequin.inspect

sleep 2.seconds

loop do
  puts "sleeping..."
  sleep 30.seconds
end

