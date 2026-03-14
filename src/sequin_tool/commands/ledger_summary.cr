require "json"

module SequinTool
  module Commands
    class LedgerSummary
      record Options, top : Int32 = 10, epochs : Int32 = 5

      def initialize(@stdout : IO = STDOUT)
      end

      def call(options : Options = Options.new, root : String = Dir.current) : Int32
        balances = read_json(File.join(root, "ledger", "state", "balances.json"), "{}").as_h
        meta = read_json(File.join(root, "ledger", "state", "meta.json"), "{}").as_h
        minted = read_json(File.join(root, "ledger", "state", "reward_epochs.json"), "[]").as_a

        top = balances
          .to_a
          .sort do |left, right|
            amount_comparison = numeric_value(right[1]) <=> numeric_value(left[1])
            next amount_comparison unless amount_comparison == 0
            left[0] <=> right[0]
          end
          .first(options.top)

        chain = string_or(meta["chain"]?, "unknown")
        version = printable_or(meta["version"]?, "?")
        tip = printable_or(meta["lastHeight"]?, "?")
        last_updated = string_or(meta["lastUpdated"]?, "n/a")

        @stdout.puts "Chain: #{chain} v#{version} | tip=#{tip}"
        @stdout.puts "Last updated: #{last_updated}"
        @stdout.puts
        @stdout.puts "Top #{top.size} balances:"
        top.each do |user, amount|
          @stdout.puts "- #{user}: #{amount.raw}"
        end

        @stdout.puts
        @stdout.puts "Recent minted reward epochs (#{Math.min(options.epochs, minted.size)}/#{minted.size}):"

        minted.last(options.epochs).reverse_each do |epoch|
          @stdout.puts "- #{epoch.as_s}"
        end

        0
      end

      private def read_json(path : String, fallback : String) : JSON::Any
        return JSON.parse(fallback) unless File.exists?(path)
        JSON.parse(File.read(path))
      end

      private def numeric_value(value : JSON::Any) : Float64
        raw = value.raw
        case raw
        when Int64
          raw.to_f
        when Float64
          raw
        else
          0.0
        end
      end

      private def printable_or(value : JSON::Any?, fallback : String) : String
        return fallback unless value
        raw = value.raw
        return fallback if raw.nil?
        raw.to_s
      end

      private def string_or(value : JSON::Any?, fallback : String) : String
        return fallback unless value
        raw = value.raw
        raw.is_a?(String) ? raw : fallback
      end
    end
  end
end
