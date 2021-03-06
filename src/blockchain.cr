require "openssl"
require "json"
require "secp256k1"

class SequinInsufficientFundsException < Exception
end

# TODO: Pull request json handling to the secp256k1 shard
class SignatureConverter
  def self.from_json(pull_parser : JSON::PullParser)
    r = ""
    s = ""
    tmp = pull_parser.read_object { | key |
      value = pull_parser.read_string
      r = value if key == "r"
      s = value if key == "s"
    }

    Secp256k1::ECDSASignature.new(
      BigInt.new(r, 16),
      BigInt.new(s, 16)
    )
  end

  def self.to_json(value, json : JSON::Builder)
    json.object do
      json.field "r", value.r.to_s
      json.field "s", value.s.to_s
    end
  end
end

class Transaction
  include JSON::Serializable

  property from_address : String | Nil
  property to_address : String
  property amount : Float64

  @[JSON::Field(emit_null: true, converter: SignatureConverter)]
  getter signature : Secp256k1::ECDSASignature?

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

    @signature.try { | sig |
      Secp256k1::Signature.verify(
        self.calculate_hash,
        Secp256k1::ECDSASignature.new(
          sig.r,
          sig.s,
        ),
        Secp256k1::Util.restore_public_key @from_address.to_s
      )
    }
  end
end

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

class BlockChain
  property chain = [] of Block
  getter difficulty = 4
  getter pending_transactions = [] of Transaction
  getter mining_reward = 10.00

  def initialize()
    @chain << self.create_genesis_block
  end

  def initialize(chain)
    @chain = chain
  end

  def create_genesis_block()
    Block.new(Time.utc.to_s, [] of Transaction, "0")
  end

  def get_latest_block
    @chain.last
  end

  def mine_pending_transactions(mining_reward_address)
    # Create a new block containing the pending transactions
    block = Block.new(
      Time.utc.to_s,
      @pending_transactions,
      self.get_latest_block.block_hash
    )

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

    balance = get_balance_of_address(trx.from_address)

    if balance < trx.amount
      raise SequinInsufficientFundsException.new("Not enough funds available in wallet for transaction")
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

  def is_block_valid(block : Block, previous_block_hash : String)
    unless block.previous_block_hash == previous_block_hash
      puts "prev hash doesn't match"
      return false
    end

    unless block.has_valid_transactions
      puts "invalid transactions"
      return false
    end

    unless block.block_hash == block.calculate_hash
      puts "bogus block_hash"
      return false
    end

    return true
  end

  def is_chain_valid()
    self.is_chain_valid(@chain)
  end

  def is_chain_valid(chain_to_validate)
    chain_to_validate.each_index { | idx |
      if idx > 0
        current_block = @chain[idx]
        previous_block = @chain[idx - 1]

        previous_block_hash = previous_block.block_hash

        unless self.is_block_valid(current_block, previous_block_hash)
          return false
        end
      end
    }

    return true
  end
end
