require "json"
require "secp256k1"

module SequinTool
  module Commands
    class TxSign
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(from : String, to : String, amount : Int64, nonce : Int64, memo : String = "", root : String = Dir.current) : Int32
        raise CLIError.new("--amount must be integer >= 1", exit_code: 1) if amount < 1
        raise CLIError.new("--nonce must be integer >= 1", exit_code: 1) if nonce < 1

        key_path = File.join(root, ".sequin", "keys", "#{from}.key")
        raise CLIError.new("Missing private key for #{from}: #{key_path}", exit_code: 1) unless File.exists?(key_path)

        pending_dir = File.join(root, "tx", "pending")
        Dir.mkdir_p(pending_dir)

        created_at = Time.utc.to_rfc3339
        tx_id = Random::Secure.hex(8)

        tx = {
          "id"         => JSON::Any.new(tx_id),
          "from"       => JSON::Any.new(from),
          "to"         => JSON::Any.new(to),
          "amount"     => JSON::Any.new(amount),
          "nonce"      => JSON::Any.new(nonce),
          "sigVersion" => JSON::Any.new(1_i64),
          "memo"       => JSON::Any.new(memo),
          "createdAt"  => JSON::Any.new(created_at),
        }

        payload = canonical_tx_json(tx)
        signature = sign_payload(payload, key_path)

        tx["signature"] = JSON::Any.new(signature)

        stamp = created_at.gsub(/[:.]/, "-")
        out_path = File.join(pending_dir, "#{stamp}__#{tx_id}.json")
        File.write(out_path, JSON::Any.new(tx).to_pretty_json + "\n")

        @stdout.puts "✅ Signed tx written: #{out_path}"
        @stdout.puts "   from=#{from} to=#{to} amount=#{amount} nonce=#{nonce}"
        0
      end

      private def canonical_tx_json(tx : Hash(String, JSON::Any)) : String
        JSON.build do |json|
          json.object do
            json.field "id", tx["id"].as_s
            json.field "from", tx["from"].as_s
            json.field "to", tx["to"].as_s
            json.field "amount", tx["amount"].as_i64
            json.field "nonce", tx["nonce"].as_i64
            json.field "sigVersion", tx["sigVersion"].as_i64
            json.field "memo", tx["memo"].as_s
            json.field "createdAt", tx["createdAt"].as_s
          end
        end
      end

      private def sign_payload(payload : String, key_path : String) : String
        private_key_hex = File.read(key_path).strip
        raise CLIError.new("Invalid private key hex", exit_code: 1) if private_key_hex.empty?

        private_key = BigInt.new(private_key_hex, 16)
        sig = Secp256k1::Signature.sign(payload, private_key)

        r_hex = Secp256k1::Util.to_padded_hex_32(sig.r)
        s_hex = Secp256k1::Util.to_padded_hex_32(sig.s)
        "secp256k1:#{r_hex}:#{s_hex}"
      rescue ex
        raise CLIError.new("Failed to sign payload: #{ex.message}", exit_code: 1)
      end
    end
  end
end
