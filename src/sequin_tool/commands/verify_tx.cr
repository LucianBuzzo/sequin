require "base64"
require "digest/sha256"
require "json"

module SequinTool
  module Commands
    class VerifyTx
      PUBKEY_PREFIX = "ed25519:"
      SPKI_PREFIX = Bytes[0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00]

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
          fail!("Invalid pubkey for #{github}: pubkey must be prefixed with ed25519:")
        end

        b64 = pubkey[PUBKEY_PREFIX.size..-1]
        raw = Base64.decode(b64)
        unless raw.size == 32
          fail!("Invalid pubkey for #{github}: ed25519 public key must decode to 32 bytes")
        end
      rescue ex
        fail!("Invalid pubkey for #{github}: #{ex.message}")
      end

      private def verify_signature!(tx : Hash(String, JSON::Any), wallet : Hash(String, JSON::Any), ctx : String)
        pubkey = wallet["pubkey"].as_s
        sig_b64 = tx["signature"].as_s

        b64 = pubkey[PUBKEY_PREFIX.size..-1]
        raw_key = Base64.decode(b64)
        signature = Base64.decode(sig_b64)

        unless signature.size == 64
          fail!("#{ctx}: signature verification error: signature must decode to 64 bytes (ed25519)")
        end

        spki_der = Bytes.new(SPKI_PREFIX.size + raw_key.size)
        SPKI_PREFIX.each_with_index { |byte, idx| spki_der[idx] = byte }
        raw_key.each_with_index { |byte, idx| spki_der[SPKI_PREFIX.size + idx] = byte }

        payload = canonical_tx_string(tx)

        pub_file = File.tempfile("sequin-pub")
        sig_file = File.tempfile("sequin-sig")
        msg_file = File.tempfile("sequin-msg")

        begin
          pub_file.write(spki_der)
          sig_file.write(signature)
          msg_file << payload
          pub_file.flush
          sig_file.flush
          msg_file.flush

          output = IO::Memory.new
          err = IO::Memory.new
          status = Process.run(
            "openssl",
            [
              "pkeyutl",
              "-verify",
              "-pubin",
              "-inkey", pub_file.path,
              "-keyform", "DER",
              "-rawin",
              "-in", msg_file.path,
              "-sigfile", sig_file.path,
            ],
            output: output,
            error: err
          )

          unless status.success?
            fail!("#{ctx}: signature verification failed")
          end
        rescue ex
          fail!("#{ctx}: signature verification error: #{ex.message}")
        ensure
          pub_file.close
          sig_file.close
          msg_file.close
        end
      end

      private def fail!(message : String) : NoReturn
        raise CLIError.new("❌ #{message}", exit_code: 1)
      end
    end
  end
end
