require "json"

module SequinTool
  module Commands
    class RewardsStatus
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(date : String? = nil, root : String = Dir.current) : Int32
        epoch_date = date || (Time.utc - 1.day).to_s("%Y-%m-%d")
        reward_path = File.join(root, "rewards", "#{epoch_date}.json")
        rewarded_prs_path = File.join(root, "ledger", "state", "rewarded_prs.json")

        raise CLIError.new("Missing reward manifest: #{reward_path}", exit_code: 1) unless File.exists?(reward_path)

        reward = JSON.parse(File.read(reward_path)).as_h
        details = reward["details"]?.try(&.as_a) || [] of JSON::Any
        rewarded_prs = File.exists?(rewarded_prs_path) ? JSON.parse(File.read(rewarded_prs_path)).as_h : ({} of String => JSON::Any)

        total = details.size
        new_claims = 0
        already_rewarded = 0
        by_user = Hash(String, Int32).new(0)

        details.each do |row|
          key = pr_key(row)
          login = row.as_h["login"]?.try(&.as_s?) || "unknown"
          by_user[login] += 1

          if rewarded_prs.has_key?(key)
            already_rewarded += 1
          else
            new_claims += 1
          end
        end

        @stdout.puts "Rewards status for #{epoch_date}"
        @stdout.puts "- manifest: #{File.basename(reward_path)}"
        @stdout.puts "- total PR entries: #{total}"
        @stdout.puts "- already rewarded: #{already_rewarded}"
        @stdout.puts "- newly eligible: #{new_claims}"

        unless by_user.empty?
          @stdout.puts "- contributors in manifest: #{by_user.size}"
        end

        0
      rescue ex : CLIError
        ErrorHandling.handle(@stderr, ex)
      rescue ex
        ErrorHandling.handle(@stderr, ex)
      end

      private def pr_key(row : JSON::Any) : String
        h = row.as_h
        if key = h["prKey"]?.try(&.as_s?)
          return key
        end

        repo = h["repo"]?.try(&.as_s?) || raise CLIError.new("Reward detail missing repo", exit_code: 1)
        number = h["number"]?.try(&.as_i64?) || raise CLIError.new("Reward detail missing number", exit_code: 1)
        "#{repo}##{number}"
      end
    end
  end
end
