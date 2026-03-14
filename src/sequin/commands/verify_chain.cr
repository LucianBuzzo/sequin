require "digest/sha256"
require "json"

module Sequin
  module Commands
    class VerifyChain
      def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
      end

      def call(root : String = Dir.current) : Int32
        blocks_dir = File.join(root, "ledger", "blocks")
        meta_path = File.join(root, "ledger", "state", "meta.json")

        return fail("Missing ledger/blocks directory") unless Dir.exists?(blocks_dir)

        files = Dir.children(blocks_dir).select(&.ends_with?(".json")).sort
        return fail("No block files found") if files.empty?

        prev_hash = nil.as(String?)
        expected_height = 0_i64

        files.each do |file|
          path = File.join(blocks_dir, file)
          block = JSON.parse(File.read(path)).as_h
          height = block["height"].as_i64
          prev_hash_value = block["prevHash"]?.try(&.raw).as(String?)

          if height != expected_height
            return fail("#{file}: expected height #{expected_height}, found #{height}")
          end

          if prev_hash_value != prev_hash
            return fail("#{file}: prevHash mismatch, expected #{printable(prev_hash)}, found #{printable(prev_hash_value)}")
          end

          prev_hash = Digest::SHA256.hexdigest(File.read(path).to_slice)
          expected_height += 1
        end

        tip_height = expected_height - 1
        meta = JSON.parse(File.read(meta_path)).as_h
        last_height = meta["lastHeight"].as_i64

        if last_height != tip_height
          return fail("meta.lastHeight mismatch: expected #{tip_height}, found #{last_height}")
        end

        @stdout.puts "✅ Chain valid (#{files.size} blocks, tip=#{tip_height})"
        0
      rescue ex : File::NotFoundError
        fail(ex.message || ex.class.name)
      rescue ex : JSON::ParseException
        fail(ex.message || ex.class.name)
      end

      private def fail(message : String) : Int32
        @stderr.puts "❌ #{message}"
        1
      end

      private def printable(value : String?) : String
        value || "null"
      end
    end
  end
end
