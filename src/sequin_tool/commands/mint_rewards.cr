require "digest/sha256"
require "json"

module SequinTool
  module Commands
    class MintRewards
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(date : String? = nil, root : String = Dir.current) : Int32
        epoch_date = date || (Time.utc - 1.day).to_s("%Y-%m-%d")

        reward_path = File.join(root, "rewards", "#{epoch_date}.json")
        raise CLIError.new("Missing reward manifest: #{reward_path}", exit_code: 1) unless File.exists?(reward_path)

        cfg_path = File.join(root, "config", "reward-repos.json")
        cfg = File.exists?(cfg_path) ? JSON.parse(File.read(cfg_path)).as_h : ({} of String => JSON::Any)

        reward = JSON.parse(File.read(reward_path)).as_h
        rewards = reward["rewards"]?.try(&.as_a) || raise CLIError.new("Reward manifest missing rewards array", exit_code: 1)
        totals = reward["totals"]?.try(&.as_h) || raise CLIError.new("Reward manifest missing totals", exit_code: 1)

        balances_path = File.join(root, "ledger", "state", "balances.json")
        meta_path = File.join(root, "ledger", "state", "meta.json")
        applied_path = File.join(root, "ledger", "state", "reward_epochs.json")
        blocks_dir = File.join(root, "ledger", "blocks")

        balances = File.exists?(balances_path) ? JSON.parse(File.read(balances_path)).as_h : ({} of String => JSON::Any)
        meta = if File.exists?(meta_path)
                 JSON.parse(File.read(meta_path)).as_h
               else
                 {
                   "chain"       => JSON::Any.new("sequin-github"),
                   "version"     => JSON::Any.new(1_i64),
                   "lastHeight"  => JSON::Any.new(0_i64),
                   "lastUpdated" => JSON::Any.new(nil),
                 }
               end
        applied = File.exists?(applied_path) ? JSON.parse(File.read(applied_path)).as_a : ([] of JSON::Any)

        if applied.any? { |entry| entry.as_s == epoch_date }
          @stdout.puts "Reward epoch #{epoch_date} already minted; nothing to do."
          return 0
        end

        distributed = rewards.sum { |row| amount_for(row) }
        expected_emission = int_from_any(totals["dailyEmission"]?) || int_from_any(cfg["dailyEmission"]?)
        if expected_emission && distributed > expected_emission
          raise CLIError.new("Distributed rewards #{distributed} exceed emission cap #{expected_emission}", exit_code: 1)
        end

        max_reward_per_user = int_from_any(cfg["maxRewardPerUser"]?)
        if max_reward_per_user
          rewards.each do |row|
            amount = amount_for(row)
            github = github_for(row)
            if amount > max_reward_per_user
              raise CLIError.new("Reward #{amount} for #{github} exceeds per-user cap #{max_reward_per_user}", exit_code: 1)
            end
          end
        end

        rewards.each do |row|
          amount = amount_for(row)
          github = github_for(row)
          raise CLIError.new("Invalid reward row", exit_code: 1) if amount < 0
          next if amount == 0

          balances[github] = JSON::Any.new(hash_int(balances, github) + amount)
        end

        last_height = hash_int(meta, "lastHeight")
        next_height = last_height + 1

        prev_block_path = File.join(blocks_dir, "#{last_height.to_s.rjust(6, '0')}.json")
        prev_hash = File.exists?(prev_block_path) ? Digest::SHA256.hexdigest(File.read(prev_block_path).to_slice) : nil

        tx_ids = rewards.compact_map do |row|
          amount = amount_for(row)
          next nil if amount <= 0
          JSON::Any.new("reward:#{epoch_date}:#{github_for(row)}")
        end

        block = {
          "height"    => JSON::Any.new(next_height),
          "prevHash"  => prev_hash ? JSON::Any.new(prev_hash) : JSON::Any.new(nil),
          "txIds"     => JSON::Any.new(tx_ids),
          "timestamp" => JSON::Any.new(Time.utc.to_rfc3339),
          "proposer"  => JSON::Any.new("github-actions[bot]"),
        }

        Dir.mkdir_p(blocks_dir)
        block_path = File.join(blocks_dir, "#{next_height.to_s.rjust(6, '0')}.json")

        write_json(block_path, JSON::Any.new(block))
        write_json(balances_path, JSON::Any.new(balances))

        meta["lastHeight"] = JSON::Any.new(next_height)
        meta["lastUpdated"] = JSON::Any.new(Time.utc.to_rfc3339)
        write_json(meta_path, JSON::Any.new(meta))

        applied << JSON::Any.new(epoch_date)
        write_json(applied_path, JSON::Any.new(applied))

        @stdout.puts "✅ Minted reward epoch #{epoch_date} in block ##{next_height}"
        0
      end

      private def write_json(path : String, any : JSON::Any)
        File.write(path, any.to_pretty_json + "\n")
      end

      private def int_from_any(value : JSON::Any?) : Int64?
        return nil unless value
        raw = value.raw
        case raw
        when Int64
          raw
        when Float64
          raw.to_i64
        else
          nil
        end
      end

      private def hash_int(hash : Hash(String, JSON::Any), key : String) : Int64
        int_from_any(hash[key]?) || 0_i64
      end

      private def github_for(row : JSON::Any) : String
        row.as_h["github"].as_s
      end

      private def amount_for(row : JSON::Any) : Int64
        int_from_any(row.as_h["amount"]?) || 0_i64
      end
    end
  end
end
