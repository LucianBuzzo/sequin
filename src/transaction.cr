
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

