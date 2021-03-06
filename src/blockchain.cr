require "openssl"
require "json"
require "secp256k1"
require "./block"
require "./transaction"

class SequinInsufficientFundsException < Exception
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
