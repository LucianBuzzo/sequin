require "./transaction"

class Block
  include JSON::Serializable

  property previous_block_hash : String
  property block_hash : String
  property transactions = [] of Transaction
  @nonce = 0
  @block_hash = ""

  def initialize(
    @timestamp : String,
    @transactions,
    @previous_block_hash : String = ""
  )
    @block_hash = self.calculate_hash.as(String)
  end

  def calculate_hash()
    new_hash = OpenSSL::Digest.new("SHA256")
    new_hash.update("#{@previous_block_hash}#{@timestamp}#{@transactions}#{@nonce}")
    new_hash.final.hexstring
  end

  def mine_block(difficulty : Int32)
    target = "0" * difficulty

    until @block_hash[0..difficulty - 1] == target
      @nonce += 1
      @block_hash = self.calculate_hash.as(String)
    end
  end

  def has_valid_transactions
    @transactions.each { | trx |
      unless trx.is_valid
        return false
      end
    }

    return true
  end
end

