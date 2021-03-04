require "../src/server"
require "../src/wallet"
require "crest"

HOST = "http://localhost:3000/api/v1"
PWD = "foobar"
server = Server.new(PWD)

describe Server do
  describe "/blockchain" do
    it "should return the blockchain" do
      server.mine
      server.mine

      response = Crest.get("#{HOST}/blockchain")
      blockchain = Array(Block).from_json(response.body)

      blockchain.size.should be > 2
    end
  end

  describe "/transaction" do
    it "should reject unauthorized requests" do
      # Mine a few blocks so that there are some sequins on the address
      server.mine
      server.mine

      to_address = "foobar"
      amount = 100

      response = Crest.post(
        "#{HOST}/transaction",
        headers: {
          "Content-Type" => "application/json"
        },
        form: {
          :to_address => to_address,
          :amount => amount,
        }.to_json,
        handle_errors: false
      )

      response.status_code.should eq(401)
    end

    it "should reject malformed requests" do
      response = Crest.post(
        "#{HOST}/transaction",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode(PWD)}"
        },
        form: {
          :foo => "bar"
        }.to_json,
        handle_errors: false
      )

      response.status_code.should eq(400)
    end

    it "should add transactions to the pool" do
      # Mine a few blocks so that there are some sequins on the address
      server.mine
      server.mine

      to_address = "foobar"
      amount = 5

      response = Crest.post(
        "#{HOST}/transaction",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode(PWD)}"
        },
        form: {
          :to_address => to_address,
          :amount => amount,
        }.to_json
      )

      response.status_code.should eq(200)

      response = Crest.get("#{HOST}/transaction_pool")

      transactions = Array(Transaction).from_json(response.body)
      transactions.size.should eq(2)
      transactions[-1].to_address.should eq(to_address)
      transactions[-1].amount.should eq(amount)
    end
  end

  describe "/balance/:address" do
    it "should return the balance of an address" do
      address = server.address

      # Mine a few blocks so that there are some sequins on the address
      server.mine
      server.mine

      to_address = Wallet.new.address
      amount = 53.0

      response = Crest.post(
        "#{HOST}/transaction",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Basic #{Base64.strict_encode(PWD)}"
        },
        form: {
          :to_address => to_address,
          :amount => amount,
        }.to_json
      )

      # Process the transaction by mining a block
      server.mine

      response = Crest.get("#{HOST}/balance/#{to_address}")

      response.body.should eq({
        :amount => amount
      }.to_json)
    end
  end

  describe "/node_address" do
    it "should store registered adresses" do
      node_address = "http://foobar.io"

      Crest.post(
        "#{HOST}/node_address",
        headers: {
          "Content-Type" => "application/json"
        },
        form: {
          :node_address => node_address,
        }.to_json
      )

      response = Crest.get("#{HOST}/node_address")

      response.body.should eq ([ node_address ].to_json)
    end
  end

  describe "/block" do
    it "should add a block to the chain" do
      blockchain = server.blockchain
      block = Block.new(
        Time.utc.to_s,
        [] of Transaction,
        blockchain.get_latest_block.block_hash
      )

      Crest.post(
        "#{HOST}/block",
        headers: {
          "Content-Type" => "application/json"
        },
        form: block.to_json
      )

      blockchain.get_latest_block.block_hash.should eq(block.block_hash)
    end

  it "should reject an invalid block" do
      blockchain = server.blockchain
      block = Block.new(
        Time.utc.to_s,
        [] of Transaction,
        "foobar"
      )

      expect_raises(Crest::UnprocessableEntity) do
        Crest.post(
          "#{HOST}/block",
          headers: {
            "Content-Type" => "application/json"
          },
          form: block.to_json
        )
      end
    end
  end
end
