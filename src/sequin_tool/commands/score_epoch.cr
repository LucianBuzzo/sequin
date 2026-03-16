require "http/client"
require "json"
require "uri"

module SequinTool
  module Commands
    class ScoreEpoch
      module Client
        abstract def merged_pr_numbers(repo : String, date : String) : Array(Int32)
        abstract def load_pr(repo : String, number : Int32) : JSON::Any
      end

      class GitHubClient
        include Client

        API_ROOT = "https://api.github.com"

        def initialize(@token : String)
        end

        def merged_pr_numbers(repo : String, date : String) : Array(Int32)
          query = URI.encode_www_form("repo:#{repo} is:pr is:merged merged:#{date}..#{date}")
          numbers = [] of Int32
          page = 1

          loop do
            path = "/search/issues?q=#{query}&per_page=100&page=#{page}"
            data = get_json(path).as_h
            items = data["items"]?.try(&.as_a) || [] of JSON::Any

            items.each do |item|
              pull_url = item.as_h["pull_request"]?.try(&.as_h["url"]?).try(&.as_s?)
              next unless pull_url
              number = pull_url.split('/').last?.try(&.to_i?)
              numbers << number if number
            end

            break if items.size < 100
            page += 1
          end

          numbers
        end

        def load_pr(repo : String, number : Int32) : JSON::Any
          owner, name = repo.split('/', 2)
          get_json("/repos/#{owner}/#{name}/pulls/#{number}")
        end

        private def get_json(path : String) : JSON::Any
          retries = 0

          loop do
            client = HTTP::Client.new(URI.parse(API_ROOT))
            headers = HTTP::Headers{
              "Accept"     => "application/vnd.github+json",
              "User-Agent" => "sequin-rewards-crystal",
              "Authorization" => "Bearer #{@token}",
            }

            response = client.get(path, headers)
            status = response.status_code

            if status >= 200 && status < 300
              return JSON.parse(response.body)
            end

            if status == 403 && response.headers["X-RateLimit-Remaining"]? == "0"
              reset_at = response.headers["X-RateLimit-Reset"]? || "unknown"
              raise CLIError.new("GitHub API rate limit exceeded (reset: #{reset_at})", exit_code: 1)
            end

            if (status == 429 || status >= 500) && retries < 3
              sleep((0.2 * (2 ** retries)).seconds)
              retries += 1
              next
            end

            raise CLIError.new("GitHub API error: #{status} for #{path}", exit_code: 1)
          end
        end
      end

      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR, @client : Client? = nil)
      end

      def call(date : String? = nil, root : String = Dir.current) : Int32
        token = ENV["GITHUB_TOKEN"]?
        if @client.nil? && (token.nil? || token.empty?)
          raise CLIError.new("GITHUB_TOKEN is required for rewards:score-epoch", exit_code: 1)
        end

        client = @client || GitHubClient.new(token.not_nil!)

        epoch_date = date || (Time.utc - 1.day).to_s("%Y-%m-%d")
        epoch_start_utc = "#{epoch_date}T00:00:00Z"
        epoch_end_utc = "#{epoch_date}T23:59:59Z"

        cfg = JSON.parse(File.read(File.join(root, "config", "reward-repos.json"))).as_h
        repos = cfg["repos"].as_a.map(&.as_s)
        exclude_logins = cfg["excludeLogins"]?.try(&.as_a.map(&.as_s)) || [] of String
        daily_emission = cfg["dailyEmission"].as_i64
        max_prs_per_user = cfg["maxPRsPerUser"].as_i64
        max_score_per_user = cfg["maxScorePerUser"].as_i64
        abort_if_no_weekday = cfg["abortIfNoMergedPRsOnWeekday"]?.try(&.as_bool) || true

        details = [] of Hash(String, JSON::Any)

        repos.each do |repo|
          numbers = client.merged_pr_numbers(repo, epoch_date)
          numbers.each do |num|
            pr = client.load_pr(repo, num).as_h
            login = pr["user"]?.try(&.as_h["login"]?).try(&.as_s?)
            next unless login
            next if exclude_logins.includes?(login)

            score = score_pr(pr)

            pr_number = pr["number"].as_i64
            details << {
              "repo"         => JSON::Any.new(repo),
              "number"       => JSON::Any.new(pr_number),
              "prKey"        => JSON::Any.new("#{repo}##{pr_number}"),
              "mergedAt"     => JSON::Any.new(pr["merged_at"]?.try(&.as_s?) || nil),
              "title"        => JSON::Any.new(pr["title"]?.try(&.as_s) || ""),
              "login"        => JSON::Any.new(login),
              "score"        => JSON::Any.new(score),
              "additions"    => JSON::Any.new(pr["additions"]?.try(&.as_i64) || 0_i64),
              "deletions"    => JSON::Any.new(pr["deletions"]?.try(&.as_i64) || 0_i64),
              "changed_files" => JSON::Any.new(pr["changed_files"]?.try(&.as_i64) || 0_i64),
              "merged_by"    => JSON::Any.new(pr["merged_by"]?.try(&.as_h["login"]?).try(&.as_s?) || nil),
            }
          end
        end

        by_user = Hash(String, Array(Hash(String, JSON::Any))).new { |h, k| h[k] = [] of Hash(String, JSON::Any) }
        details.each { |d| by_user[d["login"].as_s] << d }

        points = Hash(String, Float64).new
        by_user.each do |login, arr|
          sorted = arr.sort_by { |d| -d["score"].as_f }
          top = sorted.first(max_prs_per_user)
          total = top.sum { |d| d["score"].as_f }
          points[login] = {total, max_score_per_user.to_f}.min
        end

        merged_pr_count = details.size.to_i64
        day = Time.parse_utc("#{epoch_date}T00:00:00Z", "%Y-%m-%dT%H:%M:%SZ").day_of_week.value
        is_weekday = day >= 1 && day <= 5
        if abort_if_no_weekday && is_weekday && merged_pr_count == 0
          raise CLIError.new("No merged PR activity found for weekday epoch #{epoch_date}; aborting mint pipeline", exit_code: 1)
        end

        total_score = points.values.sum
        rewards = [] of Hash(String, JSON::Any)

        if total_score > 0
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

        distributed = rewards.sum { |r| r["amount"].as_i64 }

        output_payload = {
          "epoch"        => JSON::Any.new(epoch_date),
          "epochStartUtc" => JSON::Any.new(epoch_start_utc),
          "epochEndUtc"  => JSON::Any.new(epoch_end_utc),
          "generatedAt"  => JSON::Any.new(Time.utc.to_rfc3339),
          "config"       => JSON::Any.new({
            "repos"          => JSON::Any.new(repos.map { |r| JSON::Any.new(r) }),
            "dailyEmission"  => JSON::Any.new(daily_emission),
            "maxPRsPerUser"  => JSON::Any.new(max_prs_per_user),
            "maxScorePerUser" => JSON::Any.new(max_score_per_user),
          }),
          "totals"       => JSON::Any.new({
            "contributors" => JSON::Any.new(rewards.size.to_i64),
            "mergedPrCount" => JSON::Any.new(merged_pr_count),
            "totalScore"   => JSON::Any.new(total_score),
            "dailyEmission" => JSON::Any.new(daily_emission),
            "distributed"  => JSON::Any.new(distributed),
          }),
          "rewards"      => JSON::Any.new(rewards.map { |r| JSON::Any.new(r) }),
          "details"      => JSON::Any.new(details.map { |d| JSON::Any.new(d) }),
        }

        rewards_dir = File.join(root, "rewards")
        Dir.mkdir_p(rewards_dir)
        out_path = File.join(rewards_dir, "#{epoch_date}.json")
        File.write(out_path, JSON::Any.new(output_payload).to_pretty_json + "\n")

        @stdout.puts "Wrote #{out_path}"
        0
      end

      private def score_pr(pr : Hash(String, JSON::Any)) : Float64
        additions = pr["additions"]?.try(&.as_i64) || 0_i64
        deletions = pr["deletions"]?.try(&.as_i64) || 0_i64
        lines = additions + deletions
        return 0.0 if lines < 10

        base = 10.0
        size = {20.0, Math.log(1 + lines) * 3.5}.min
        files = {8.0, (pr["changed_files"]?.try(&.as_i64) || 0_i64).to_f * 0.5}.min

        merged_by = pr["merged_by"]?.try(&.as_h["login"]?).try(&.as_s?)
        author = pr["user"]?.try(&.as_h["login"]?).try(&.as_s?)
        self_merge_penalty = (merged_by && author && merged_by == author) ? -6.0 : 0.0
        draft_penalty = pr["draft"]?.try(&.as_bool) ? -5.0 : 0.0

        {0.0, base + size + files + self_merge_penalty + draft_penalty}.max
      end
    end
  end
end
