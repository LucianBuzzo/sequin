require "openssl"
require "json"
require "secp256k1"

class Transaction
  property from_address : String | Nil
  property to_address : String
  property amount : Int32

  def initialize(
    @from_address,
    @to_address,
    @amount
  )
  end

  def calculate_hash
    new_hash = OpenSSL::Digest.new("SHA256")
    new_hash.update("#{@from_address}#{@to_address}#{@amount}")
    new_hash.final.hexstring
  end

  def sign_transaction(signing_key)
    public_key = Secp256k1::Util.public_key_compressed_prefix signing_key.public_key
    if public_key != @from_address
      raise Exception.new("You cannot sign transactions for other wallets")
    end

    hash_tx = self.calculate_hash
    @signature = Secp256k1::Signature.sign(hash_tx, signing_key.private_key)
  end

  def is_valid
    if @from_address == nil
      return true
    end


    if !@signature
      raise Exception.new("No signature in this transaction")
    end

    Secp256k1::Signature.verify(
      self.calculate_hash,
      @signature.as Secp256k1::ECDSASignature,
      Secp256k1::Util.restore_public_key @from_address.to_s
    )
  end
end

class Block
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

class BlockChain
  getter chain = [] of Block
  getter difficulty = 4
  getter pending_transactions = [] of Transaction
  getter mining_reward = 100

  def initialize()
    @chain << self.create_genesis_block
  end

  def create_genesis_block()
    Block.new(Time.utc.to_s, [] of Transaction, "0")
  end

  def get_latest_block
    @chain.last
  end

  def mine_pending_transactions(mining_reward_address)
    # Create a new block containing the pending transactions
    block = Block.new(Time.utc.to_s, @pending_transactions)

    # Mine the block and push it onto the chain
    block.mine_block(@difficulty)
    @chain.push(block)

    # Create a new transaction, rewarding the miner
    @pending_transactions = [
      Transaction.new(nil, mining_reward_address, @mining_reward)
    ]
  end

  def add_transaction(trx)
    unless trx.from_address && trx.to_address
      raise Exception.new("Transaction must include from and to address")
    end

    unless trx.is_valid
      raise Exception.new("Cannot add invalid transaction to the chain")
    end

    @pending_transactions.push(trx)
  end

  def get_balance_of_address(address)
    balance = 0

    @chain.each { | block |
      block.transactions.each { | trx |
        if trx.from_address == address
          balance -= trx.amount
        end

        if trx.to_address == address
          balance += trx.amount
        end
      }
    }

    return balance
  end

  def add_block(newBlock)
    newBlock.previous_block_hash = self.get_latest_block.block_hash
    newBlock.mine_block(@difficulty)
    @chain.push(newBlock)
  end

  def is_chain_valid()
    @chain.each_index { | idx |
      if idx > 0
        current_block = @chain[idx]
        previous_block = @chain[idx - 1]

        unless current_block.has_valid_transactions
          return false
        end

        unless current_block.block_hash == current_block.calculate_hash
          return false
        end

        unless current_block.previous_block_hash == previous_block.block_hash
          return false
        end
      end
    }

    return true
  end
end
