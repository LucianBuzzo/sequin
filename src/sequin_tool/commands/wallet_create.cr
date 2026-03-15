require "json"
require "secp256k1"

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

        keypair = Secp256k1::Keypair.new
        private_key_hex = keypair.get_secret
        public_key_hex = Secp256k1::Util.public_key_compressed_prefix(keypair.public_key)

        File.write(key_path, private_key_hex + "\n")

        wallet = {
          "github"    => JSON::Any.new(github),
          "pubkey"    => JSON::Any.new("secp256k1:#{public_key_hex}"),
          "createdAt" => JSON::Any.new(Time.utc.to_rfc3339),
        }

        wallet_path = File.join(wallets_dir, "#{github}.json")
        File.write(wallet_path, JSON::Any.new(wallet).to_pretty_json + "\n")

        @stdout.puts "✅ Created wallet file: #{wallet_path}"
        @stdout.puts "✅ Created private key: #{key_path}"
        @stdout.puts "⚠️ Keep private key secret. Do NOT commit .sequin/keys/*"
        0
      end
    end
  end
end
