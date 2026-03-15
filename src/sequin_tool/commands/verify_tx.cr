require "digest/sha256"
require "json"
require "secp256k1"

module SequinTool
  module Commands
    class VerifyTx
      PUBKEY_PREFIX = "secp256k1:"
      SIGNATURE_PREFIX = "secp256k1:"

      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(root : String = Dir.current) : Int32
        wallets_dir = File.join(root, "wallets")
        pending_dir = File.join(root, "tx", "pending")
        balances_path = File.join(root, "ledger", "state", "balances.json")
        nonces_path = File.join(root, "ledger", "state", "nonces.json")

        balances = read_numeric_hash(balances_path)
        nonces = read_numeric_hash(nonces_path)

        wallet_files = list_json_files(wallets_dir)
        wallets = Hash(String, Hash(String, JSON::Any)).new
        pubkeys = Set(String).new

        wallet_files.each do |wf|
          wallet = JSON.parse(File.read(wf)).as_h
          github = wallet["github"]?.try(&.as_s) || fail!("#{File.basename(wf)}: missing github")
          pubkey = wallet["pubkey"]?.try(&.as_s) || fail!("#{File.basename(wf)}: missing pubkey")

          filename = File.basename(wf, ".json")
          fail!("Wallet filename #{filename}.json must match github field #{github}") unless filename == github
          fail!("Duplicate wallet for #{github}") if wallets.has_key?(github)
          fail!("Duplicate public key for #{github}") if pubkeys.includes?(pubkey)

          validate_pubkey(pubkey, github)

          wallets[github] = wallet
          pubkeys << pubkey
        end

        @stdout.puts "✅ Loaded #{wallets.size} wallet(s)"

        tx_files = list_json_files(pending_dir)
        tx_ids = Set(String).new
        tx_hashes = Set(String).new

        tx_files.each do |tf|
          tx = JSON.parse(File.read(tf)).as_h
          ctx = File.basename(tf)

          required = ["id", "from", "to", "amount", "nonce", "sigVersion", "createdAt", "signature"]
          required.each do |key|
            fail!("#{ctx}: missing #{key}") unless tx.has_key?(key)
          end

          id = tx["id"].as_s
          fail!("#{ctx}: duplicate tx id #{id}") if tx_ids.includes?(id)
          tx_ids << id

          hash = tx_hash(tx)
          fail!("#{ctx}: duplicate tx payload hash #{hash}") if tx_hashes.includes?(hash)
          tx_hashes << hash

          from = tx["from"].as_s
          to = tx["to"].as_s
          amount = int_value(tx["amount"], "#{ctx}: amount")
          nonce = int_value(tx["nonce"], "#{ctx}: nonce")
          sig_version = int_value(tx["sigVersion"], "#{ctx}: sigVersion")

          fail!("#{ctx}: sender wallet #{from} not registered") unless wallets.has_key?(from)
          fail!("#{ctx}: receiver wallet #{to} not registered") unless wallets.has_key?(to)
          fail!("#{ctx}: amount must be integer >= 1") unless amount >= 1
          fail!("#{ctx}: nonce must be integer >= 1") unless nonce >= 1
          fail!("#{ctx}: sigVersion must be 1") unless sig_version == 1

          expected_nonce = (nonces[from]? || 0_i64) + 1
          if nonce != expected_nonce
            fail!("#{ctx}: nonce mismatch for #{from}; expected #{expected_nonce}, got #{nonce}")
          end

          balance = balances[from]? || 0_i64
          if balance < amount
            fail!("#{ctx}: insufficient funds for #{from}; have #{balance}, need #{amount}")
          end

          verify_signature!(tx, wallets[from], ctx)

          nonces[from] = nonce
          balances[from] = balance - amount
          balances[to] = (balances[to]? || 0_i64) + amount
        end

        @stdout.puts "✅ Validated #{tx_files.size} pending transaction(s)"
        0
      rescue ex : CLIError
        ErrorHandling.handle(@stderr, ex)
      rescue ex
        ErrorHandling.handle(@stderr, ex)
      end

      private def list_json_files(dir : String) : Array(String)
        return [] of String unless Dir.exists?(dir)
        Dir.children(dir).select(&.ends_with?(".json")).sort.map { |f| File.join(dir, f) }
      end

      private def read_numeric_hash(path : String) : Hash(String, Int64)
        return {} of String => Int64 unless File.exists?(path)
        json = JSON.parse(File.read(path)).as_h
        out = Hash(String, Int64).new
        json.each do |k, v|
          out[k] = int_value(v, "#{path}:#{k}")
        end
        out
      end

      private def int_value(value : JSON::Any, context : String) : Int64
        raw = value.raw
        case raw
        when Int64
          raw
        when Float64
          raw.to_i64
        else
          fail!("#{context} must be integer")
        end
      end

      private def tx_hash(tx : Hash(String, JSON::Any)) : String
        Digest::SHA256.hexdigest(canonical_tx_string(tx))
      end

      private def canonical_tx_string(tx : Hash(String, JSON::Any)) : String
        JSON.build do |json|
          json.object do
            json.field "id", tx["id"].as_s
            json.field "from", tx["from"].as_s
            json.field "to", tx["to"].as_s
            json.field "amount", int_value(tx["amount"], "amount")
            json.field "nonce", int_value(tx["nonce"], "nonce")
            json.field "sigVersion", int_value(tx["sigVersion"], "sigVersion")
            json.field "memo", tx["memo"]?.try(&.as_s) || ""
            json.field "createdAt", tx["createdAt"].as_s
          end
        end
      end

      private def validate_pubkey(pubkey : String, github : String)
        unless pubkey.starts_with?(PUBKEY_PREFIX)
          fail!("Invalid pubkey for #{github}: pubkey must be prefixed with secp256k1:")
        end

        encoded = pubkey[PUBKEY_PREFIX.size..-1]
        unless encoded.matches?(/\A(02|03)[0-9a-fA-F]{64}\z/)
          fail!("Invalid pubkey for #{github}: expected compressed secp256k1 pubkey hex")
        end
      end

      private def verify_signature!(tx : Hash(String, JSON::Any), wallet : Hash(String, JSON::Any), ctx : String)
        pubkey = wallet["pubkey"].as_s[PUBKEY_PREFIX.size..-1]
        signature = tx["signature"].as_s
        payload = canonical_tx_string(tx)

        unless signature.starts_with?(SIGNATURE_PREFIX)
          fail!("#{ctx}: signature must be prefixed with secp256k1:")
        end

        parts = signature[SIGNATURE_PREFIX.size..-1].split(":")
        unless parts.size == 2
          fail!("#{ctx}: signature must be formatted as secp256k1:<r_hex>:<s_hex>")
        end

        r_hex, s_hex = parts
        unless r_hex.matches?(/\A[0-9a-fA-F]{64}\z/) && s_hex.matches?(/\A[0-9a-fA-F]{64}\z/)
          fail!("#{ctx}: signature r/s must be 64-char hex values")
        end

        sig = Secp256k1::ECDSASignature.new(BigInt.new(r_hex, 16), BigInt.new(s_hex, 16))
        point = Secp256k1::Util.restore_public_key(pubkey)

        valid = Secp256k1::Signature.verify(payload, sig, point)
        fail!("#{ctx}: signature verification failed") unless valid
      rescue ex : CLIError
        raise ex
      rescue ex
        fail!("#{ctx}: signature verification error: #{ex.message}")
      end

      private def fail!(message : String) : NoReturn
        raise CLIError.new("❌ #{message}", exit_code: 1)
      end
    end
  end
end
