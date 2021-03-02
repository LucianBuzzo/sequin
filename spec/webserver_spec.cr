require "../src/server"
require "../src/wallet"
require "crest"

host = "http://localhost:3000/api/v1"
server = Server.new

describe Server do
  describe "/transaction" do
    it "should reject malformed requests" do
      response = Crest.post(
        "#{host}/transaction",
        headers: {
          "Content-Type" => "application/json"
        },
        form: {
          :foo => "bar"
        }.to_json,
        handle_errors: false
      )

      response.status_code.should eq(400)

      response = Crest.get("#{host}/transaction_pool")

      # The transaction pool should be empty
      response.body.should eq("[]")
    end

    it "should add transactions to the pool" do
      # Mine a few blocks so that there are some sequins on the address
      server.mine
      server.mine

      to_address = "foobar"
      amount = 100

      response = Crest.post(
        "#{host}/transaction",
        headers: {
          "Content-Type" => "application/json"
        },
        form: {
          :to_address => to_address,
          :amount => amount,
        }.to_json
      )

      response.status_code.should eq(200)

      response = Crest.get("#{host}/transaction_pool")

      # The transaction pool should be empty
      transactions = Array(Transaction).from_json(response.body)
      transactions.size.should eq(2)
      transactions[-1].to_address.should eq(to_address)
      transactions[-1].amount.should eq(amount)
    end
  end

  describe "/balance/:address" do
    it "should return the balance of an address", focus: true do
      address = server.address

      # Mine a few blocks so that there are some sequins on the address
      server.mine
      server.mine

      to_address = Wallet.new.address
      amount = 53.0

      response = Crest.post(
        "#{host}/transaction",
        headers: {
          "Content-Type" => "application/json"
        },
        form: {
          :to_address => to_address,
          :amount => amount,
        }.to_json
      )

      # Process the transaction by mining a block
      server.mine

      response = Crest.get("#{host}/balance/#{to_address}")

      response.body.should eq({
        :amount => amount
      }.to_json)
    end
  end
end
