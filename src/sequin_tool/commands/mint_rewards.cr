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
        totals = reward["totals"]?.try(&.as_h) || raise CLIError.new("Reward manifest missing totals", exit_code: 1)

        balances_path = File.join(root, "ledger", "state", "balances.json")
        meta_path = File.join(root, "ledger", "state", "meta.json")
        applied_path = File.join(root, "ledger", "state", "reward_epochs.json")
        rewarded_prs_path = File.join(root, "ledger", "state", "rewarded_prs.json")
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
        rewarded_prs = File.exists?(rewarded_prs_path) ? JSON.parse(File.read(rewarded_prs_path)).as_h : ({} of String => JSON::Any)

        details = reward["details"]?.try(&.as_a) || [] of JSON::Any

        # New idempotent path (preferred): mint from PR-level details while skipping already rewarded PR keys.
        # Backward-compatible fallback: old manifests without details use static rewards array and epoch gate.
        if details.empty?
          return mint_legacy_epoch!(epoch_date, reward, cfg, totals, balances, meta, applied, applied_path, balances_path, meta_path, blocks_dir)
        end

        eligible = details.select do |row|
          key = pr_key(row)
          !rewarded_prs.has_key?(key)
        end

        if eligible.empty?
          @stdout.puts "No new reward claims for epoch #{epoch_date}; nothing to mint."
          return 0
        end

        daily_emission = int_from_any(totals["dailyEmission"]?) || int_from_any(cfg["dailyEmission"]?) || 0_i64
        max_prs_per_user = int_from_any(cfg["maxPRsPerUser"]?) || 5_i64
        max_score_per_user = int_from_any(cfg["maxScorePerUser"]?) || 120_i64

        points = score_points_by_user(eligible, max_prs_per_user, max_score_per_user)
        total_score = points.values.sum

        rewards = [] of Hash(String, JSON::Any)
        if total_score > 0 && daily_emission > 0
          points.each do |login, score|
            amount = ((daily_emission.to_f * score) / total_score).floor.to_i64
            next if amount <= 0
            rewards << {
              "github" => JSON::Any.new(login),
              "amount" => JSON::Any.new(amount),
              "score"  => JSON::Any.new(score),
            }
          end

          rewards.sort! do |a, b|
            amount_cmp = b["amount"].as_i64 <=> a["amount"].as_i64
            next amount_cmp unless amount_cmp == 0
            a["github"].as_s <=> b["github"].as_s
          end
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
          next if amount <= 0
          balances[github] = JSON::Any.new(hash_int(balances, github) + amount)
        end

        next_height = hash_int(meta, "lastHeight")
        minted_block_height = nil.as(Int64?)

        if rewards.any? { |r| amount_for(r) > 0 }
          next_height += 1
          minted_block_height = next_height

          prev_block_path = File.join(blocks_dir, "#{(next_height - 1).to_s.rjust(6, '0')}.json")
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

          meta["lastHeight"] = JSON::Any.new(next_height)
          meta["lastUpdated"] = JSON::Any.new(Time.utc.to_rfc3339)
          write_json(meta_path, JSON::Any.new(meta))
        end

        eligible.each do |row|
          key = pr_key(row)
          repo = row.as_h["repo"].as_s
          pr_number = int_from_any(row.as_h["number"]?) || 0_i64
          login = row.as_h["login"]?.try(&.as_s?) || ""
          merged_at = row.as_h["mergedAt"]?.try(&.as_s?)

          rewarded_prs[key] = JSON::Any.new({
            "repo"       => JSON::Any.new(repo),
            "prNumber"   => JSON::Any.new(pr_number),
            "login"      => JSON::Any.new(login),
            "epoch"      => JSON::Any.new(epoch_date),
            "mergedAt"   => JSON::Any.new(merged_at),
            "mintedAt"   => JSON::Any.new(Time.utc.to_rfc3339),
            "mintBlock"  => minted_block_height ? JSON::Any.new(minted_block_height) : JSON::Any.new(nil),
          })
        end

        write_json(rewarded_prs_path, JSON::Any.new(rewarded_prs))
        write_json(balances_path, JSON::Any.new(balances))

        unless applied.any? { |entry| entry.as_s == epoch_date }
          applied << JSON::Any.new(epoch_date)
          write_json(applied_path, JSON::Any.new(applied))
        end

        distributed = rewards.sum { |r| amount_for(r) }
        @stdout.puts "✅ Minted incremental reward epoch #{epoch_date}: +#{eligible.size} PR claim(s), distributed=#{distributed}"
        0
      end

      private def mint_legacy_epoch!(
        epoch_date : String,
        reward : Hash(String, JSON::Any),
        cfg : Hash(String, JSON::Any),
        totals : Hash(String, JSON::Any),
        balances : Hash(String, JSON::Any),
        meta : Hash(String, JSON::Any),
        applied : Array(JSON::Any),
        applied_path : String,
        balances_path : String,
        meta_path : String,
        blocks_dir : String
      ) : Int32
        if applied.any? { |entry| entry.as_s == epoch_date }
          @stdout.puts "Reward epoch #{epoch_date} already minted; nothing to do."
          return 0
        end

        rewards = reward["rewards"]?.try(&.as_a) || raise CLIError.new("Reward manifest missing rewards array", exit_code: 1)

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

      private def score_points_by_user(details : Array(JSON::Any), max_prs_per_user : Int64, max_score_per_user : Int64) : Hash(String, Float64)
        by_user = Hash(String, Array(JSON::Any)).new { |h, k| h[k] = [] of JSON::Any }
        details.each do |row|
          login = row.as_h["login"]?.try(&.as_s?)
          next unless login
          by_user[login] << row
        end

        points = Hash(String, Float64).new
        by_user.each do |login, rows|
          sorted = rows.sort_by { |r| -(r.as_h["score"]?.try(&.as_f?) || 0.0) }
          top = sorted.first(max_prs_per_user)
          total = top.sum { |r| r.as_h["score"]?.try(&.as_f?) || 0.0 }
          points[login] = {total, max_score_per_user.to_f}.min
        end
        points
      end

      private def pr_key(row : JSON::Any) : String
        h = row.as_h
        if key = h["prKey"]?.try(&.as_s?)
          return key
        end

        repo = h["repo"]?.try(&.as_s?) || raise CLIError.new("Reward detail missing repo", exit_code: 1)
        number = int_from_any(h["number"]?) || raise CLIError.new("Reward detail missing number", exit_code: 1)
        "#{repo}##{number}"
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

      private def github_for(row : JSON::Any | Hash(String, JSON::Any)) : String
        case row
        when JSON::Any
          row.as_h["github"].as_s
        when Hash(String, JSON::Any)
          row["github"].as_s
        else
          raise "unreachable"
        end
      end

      private def amount_for(row : JSON::Any | Hash(String, JSON::Any)) : Int64
        case row
        when JSON::Any
          int_from_any(row.as_h["amount"]?) || 0_i64
        when Hash(String, JSON::Any)
          int_from_any(row["amount"]?) || 0_i64
        else
          raise "unreachable"
        end
      end
    end
  end
end
