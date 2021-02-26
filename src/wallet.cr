require "secp256k1"

class Wallet
  def initialize()
    rand = Random::Secure.random_bytes(64)
    hash = OpenSSL::Digest.new("SHA256").update(rand).final.hexstring

    # SHA256 will generate a 64 character hash in base 16, which can be converted to a BigInt. The keypair seed has to be a BigInt
    seed = BigInt.new(hash, 16)
    @keypair = Secp256k1::Keypair.new seed
    @keypair.get_secret
  end

  def address
    Secp256k1::Util.public_key_compressed_prefix @keypair.public_key
  end

  def create_transaction(to_address, amount)
    trx = Transaction.new(self.address, to_address, amount)
    trx.sign_transaction(@keypair)

    return trx
  end
end
