require "base64"
require "json"

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
        sig = sign_payload(payload, key_path)

        tx["signature"] = JSON::Any.new(Base64.strict_encode(sig))

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

      private def sign_payload(payload : String, key_path : String) : Bytes
        msg_path = File.join(Dir.tempdir, "sequin-#{Random::Secure.hex(6)}.msg")
        sig_path = File.join(Dir.tempdir, "sequin-#{Random::Secure.hex(6)}.sig")

        begin
          File.write(msg_path, payload)
          output = IO::Memory.new
          error = IO::Memory.new
          status = Process.run(
            "openssl",
            ["pkeyutl", "-sign", "-inkey", key_path, "-rawin", "-in", msg_path, "-out", sig_path],
            output: output,
            error: error
          )

          unless status.success?
            err_s = error.to_s
            out_s = output.to_s
            msg = !err_s.empty? ? err_s : (!out_s.empty? ? out_s : "command failed")
            raise CLIError.new("openssl signing failed: #{msg}", exit_code: 1)
          end

          File.read(sig_path).to_slice
        ensure
          File.delete?(msg_path)
          File.delete?(sig_path)
        end
      end
    end
  end
end
