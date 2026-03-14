require "base64"
require "json"

module SequinTool
  module Commands
    class WalletCreate
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(github : String, root : String = Dir.current) : Int32
        keys_dir = File.join(root, ".sequin", "keys")
        wallets_dir = File.join(root, "wallets")
        Dir.mkdir_p(keys_dir)
        Dir.mkdir_p(wallets_dir)

        key_path = File.join(keys_dir, "#{github}.key")
        if File.exists?(key_path)
          raise CLIError.new("Private key already exists: #{key_path}", exit_code: 1)
        end

        pub_der_path = File.join(Dir.tempdir, "sequin-#{Random::Secure.hex(6)}.pub.der")

        begin
          run!("openssl", ["genpkey", "-algorithm", "Ed25519", "-out", key_path])
          run!("openssl", ["pkey", "-in", key_path, "-pubout", "-outform", "DER", "-out", pub_der_path])

          pub_bytes = File.read(pub_der_path).to_slice
          raise CLIError.new("Unexpected pubkey length", exit_code: 1) if pub_bytes.size < 32

          raw_pub = pub_bytes[pub_bytes.size - 32, 32]
          pub_b64 = Base64.strict_encode(raw_pub)

          wallet = {
            "github"    => JSON::Any.new(github),
            "pubkey"    => JSON::Any.new("ed25519:#{pub_b64}"),
            "createdAt" => JSON::Any.new(Time.utc.to_rfc3339),
          }

          wallet_path = File.join(wallets_dir, "#{github}.json")
          File.write(wallet_path, JSON::Any.new(wallet).to_pretty_json + "\n")

          @stdout.puts "✅ Created wallet file: #{wallet_path}"
          @stdout.puts "✅ Created private key: #{key_path}"
          @stdout.puts "⚠️ Keep private key secret. Do NOT commit .sequin/keys/*"
          0
        ensure
          File.delete?(pub_der_path)
        end
      end

      private def run!(command : String, args : Array(String))
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run(command, args, output: output, error: error)
        unless status.success?
          err_s = error.to_s
          out_s = output.to_s
          msg = !err_s.empty? ? err_s : (!out_s.empty? ? out_s : "command failed")
          raise CLIError.new("#{command} #{args.join(" ")} failed: #{msg}", exit_code: 1)
        end
      end
    end
  end
end
