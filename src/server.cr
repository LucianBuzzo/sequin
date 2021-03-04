require "base64"
require "crest"
require "kemal"
require "./blockchain"
require "./wallet"

SEED_NODE_ADDRESSES = [
  "https://88809ab7bbb81832c2cdfa142873ce3a.balena-devices.com"
]

LOCAL_NODE_ADDRESS = "https://#{ENV["BALENA_DEVICE_UUID"]}.balena-devices.com"

class Server
  AUTH = "Authorization"
  BASIC = "Basic"

  @node_addresses = [ LOCAL_NODE_ADDRESS ]

  def initialize
    initialize(nil)
  end

  def initialize(pwd : String?)
    @wallet = Wallet.new
    @blockchain = BlockChain.new

    if pwd
      @pwd = pwd
    else
      unless ENV.has_key?("PASSWORD")
        raise Exception.new("Looks like you for got to set the 'PASSWORD' env var")
      end

      @pwd = ENV["PASSWORD"]
    end

    before_post "/api/v1/transaction" do | env |
      unless self.authorized(env)
        halt env, status_code: 401, response: "Unauthorized"
      end
    end

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

    get "/api/v1/balance/:address" do | env |
      address = env.params.url["address"]
      balance = @blockchain.get_balance_of_address(address)
      env.response.content_type = "application/json"
      {
        :amount => balance
      }.to_json
    end

    get "/api/v1/blockchain" do | env |
      env.response.content_type = "application/json"
      @blockchain.chain.to_json
    end

    post "/api/v1/node_address" do | env |
      payload = env.params.json

      unless payload.has_key?("node_address")
        halt env, status_code: 400, response: "Missing required fields for registration"
      end

      node_address = env.params.json["node_address"].as(String)

      @node_addresses.push(node_address)

      halt env, response: "ack"
    end

    get "/api/v1/node_address" do | env |
      env.response.content_type = "application/json"
      @node_addresses.to_json
    end

    spawn do
      Kemal.run(3000, nil)
    end



    sleep 1.seconds

    puts "Server started"

    self.scan_peers
  end

  def authorized(env)
    if env.request.headers[AUTH]?
      if value = env.request.headers[AUTH]
        if value.size > 0 && value.starts_with?("Basic")
          auth_pwd = Base64.decode_string(value[BASIC.size + 1..-1])

          if auth_pwd == @pwd
            return true
          end
        end
      end
    end

    false
  end

  def start_miner
    while true
      self.mine
      block = @blockchain.get_latest_block
      puts "mined block #{block.block_hash}"
      balance = @blockchain.get_balance_of_address(@wallet.address)
      puts "new balance #{balance}"

      sleep 10.seconds
    end
  end

  def scan_peers
    puts "Retrieving peer addresses"
    peers = [] of String
    @node_addresses.each { | addr |
      if addr != LOCAL_NODE_ADDRESS
        puts "registering with peer: #{addr}"
        ack = Crest.post(
          "#{addr}/node_address",
          headers: {
            "Content-Type" => "application/json"
          },
          form: {
            :node_address => LOCAL_NODE_ADDRESS,
          }.to_json,
          handle_errors: false
        )

        puts ack.pretty_inspect

        if ack.status_code == 200
          puts "successfully registered with peer: #{addr}"
          peers.push(addr)
          response = Crest.get(
            "#{addr}/node_address",
            headers: {
              "Content-Type" => "application/json"
            }
          )

          Array(String).from_json(response.body).each { | peer |
            peers.push(peer)
          }
        else
          puts "unable to register with peer: #{addr}"
        end
      end
    }

    @node_addresses = peers
  end

  def mine
    @blockchain.mine_pending_transactions(@wallet.address)
  end

  def address
    @wallet.address
  end

  def reward
    @blockchain.mining_reward
  end

  def stop
    Kemal.stop
  end
end
