require "json"

module SequinTool
  module Commands
    class RepoLint
      INCLUDE_DIRS = ["schemas", "ledger", "wallets", "tx", "rewards", "config"]

      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(root : String = Dir.current) : Int32
        checked_json = 0

        INCLUDE_DIRS.each do |dir|
          abs = File.join(root, dir)
          next unless Dir.exists?(abs)

          walk(abs).each do |path|
            next unless path.ends_with?(".json")
            begin
              JSON.parse(File.read(path))
              checked_json += 1
            rescue ex : JSON::ParseException
              raise CLIError.new("Invalid JSON in #{relative(root, path)}: #{ex.message}", exit_code: 1)
            end
          end
        end

        @stdout.puts "✅ JSON files checked: #{checked_json}"
        0
      rescue ex : CLIError
        ErrorHandling.handle(@stderr, ex)
      end

      private def walk(dir : String) : Array(String)
        out = [] of String
        Dir.each_child(dir) do |name|
          next if [".git", "node_modules", ".sequin"].includes?(name)
          path = File.join(dir, name)
          if Dir.exists?(path)
            out.concat(walk(path))
          else
            out << path
          end
        end
        out
      end

      private def relative(root : String, path : String) : String
        path.starts_with?(root + "/") ? path[root.size + 1..] : path
      end
    end
  end
end
