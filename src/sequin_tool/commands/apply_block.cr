require "digest/sha256"
require "json"

module SequinTool
  module Commands
    class ApplyBlock
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(root : String = Dir.current) : Int32
        blocks_dir = File.join(root, "ledger", "blocks")
        balances_path = File.join(root, "ledger", "state", "balances.json")
        nonces_path = File.join(root, "ledger", "state", "nonces.json")
        meta_path = File.join(root, "ledger", "state", "meta.json")
        pending_dir = File.join(root, "tx", "pending")

        Dir.mkdir_p(blocks_dir)

        pending_files = Dir.exists?(pending_dir) ? Dir.children(pending_dir).select(&.ends_with?(".json")).sort : [] of String

        if pending_files.empty?
          @stdout.puts "No pending tx files; nothing to apply."
          return 0
        end

        balances = read_hash_any(balances_path)
        nonces = read_hash_any(nonces_path)
        meta = read_hash_any(meta_path)

        txs = pending_files.map { |file| {file: file, data: JSON.parse(File.read(File.join(pending_dir, file))).as_h} }

        txs.each do |tx|
          data = tx[:data]
          from = data["from"].as_s
          to = data["to"].as_s
          amount = as_int(data["amount"])
          nonce = as_int(data["nonce"])

          from_balance = hash_int(balances, from)
          raise CLIError.new("Insufficient balance for #{from}", exit_code: 1) if from_balance < amount

          expected_nonce = hash_int(nonces, from) + 1
          if nonce != expected_nonce
            raise CLIError.new("Bad nonce for #{from}: expected #{expected_nonce}, got #{nonce}", exit_code: 1)
          end

          balances[from] = JSON::Any.new(from_balance - amount)
          balances[to] = JSON::Any.new(hash_int(balances, to) + amount)
          nonces[from] = JSON::Any.new(nonce)
        end

        last_height = hash_int(meta, "lastHeight")
        next_height = last_height + 1

        prev_block_path = File.join(blocks_dir, "#{last_height.to_s.rjust(6, '0')}.json")
        prev_hash = File.exists?(prev_block_path) ? Digest::SHA256.hexdigest(File.read(prev_block_path).to_slice) : nil

        block = {
          "height"    => JSON::Any.new(next_height),
          "prevHash"  => prev_hash ? JSON::Any.new(prev_hash) : JSON::Any.new(nil),
          "txIds"     => JSON::Any.new(txs.map { |t| JSON::Any.new(t[:data]["id"].as_s) }),
          "timestamp" => JSON::Any.new(Time.utc.to_rfc3339),
          "proposer"  => JSON::Any.new("github-actions[bot]"),
        }

        block_path = File.join(blocks_dir, "#{next_height.to_s.rjust(6, '0')}.json")
        write_json(block_path, JSON::Any.new(block))
        write_json(balances_path, JSON::Any.new(balances))
        write_json(nonces_path, JSON::Any.new(nonces))

        meta["lastHeight"] = JSON::Any.new(next_height)
        meta["lastUpdated"] = JSON::Any.new(Time.utc.to_rfc3339)
        write_json(meta_path, JSON::Any.new(meta))

        pending_files.each { |file| File.delete(File.join(pending_dir, file)) }

        @stdout.puts "Applied block ##{next_height} with #{txs.size} tx(s)"
        0
      end

      private def read_hash_any(path : String) : Hash(String, JSON::Any)
        return {} of String => JSON::Any unless File.exists?(path)
        JSON.parse(File.read(path)).as_h
      end

      private def as_int(value : JSON::Any) : Int64
        raw = value.raw
        case raw
        when Int64
          raw
        when Float64
          raw.to_i64
        else
          raise CLIError.new("Expected integer numeric value", exit_code: 1)
        end
      end

      private def hash_int(hash : Hash(String, JSON::Any), key : String) : Int64
        value = hash[key]?
        return 0_i64 unless value
        as_int(value)
      end

      private def write_json(path : String, any : JSON::Any)
        File.write(path, any.to_pretty_json + "\n")
      end
    end
  end
end
