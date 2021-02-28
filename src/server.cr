require "kemal"
require "./blockchain"
require "./wallet"

class Server
  def initialize
    @wallet = Wallet.new
    @blockchain = BlockChain.new

    post "/api/v1/transaction" do | env |
      payload = env.params.json

      unless payload.has_key?("to_address") && payload.has_key?("amount")
        halt env, status_code: 400, response: "Missing required fields for transaction"
      end

      to_address = env.params.json["to_address"].as(String)
      amount = env.params.json["amount"].as(Int64 | Float64).to_f

      trx = @wallet.create_transaction(to_address, amount)

      @blockchain.add_transaction(trx)

      trx.to_json()
    end

    get "/api/v1/transaction_pool" do | env |
      pool = @blockchain.pending_transactions.to_json
      env.response.content_type = "application/json"
      pool
    end

    spawn do
      Kemal.run
    end

    sleep 1.seconds

    puts "Server started"
  end

  def mine
    @blockchain.mine_pending_transactions(@wallet.address)
  end

  def stop
    Kemal.stop
  end
end
