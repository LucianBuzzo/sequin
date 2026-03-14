require "json"

module SequinTool
  module Commands
    class TxNextNonce
      def initialize(@stdout : IO = STDOUT)
      end

      def call(user : String, root : String = Dir.current) : Int32
        nonces_path = File.join(root, "ledger", "state", "nonces.json")
        nonces = File.exists?(nonces_path) ? JSON.parse(File.read(nonces_path)).as_h : ({} of String => JSON::Any)
        current = nonces[user]?.try { |v| v.as_i64 } || 0_i64
        @stdout.puts(current + 1)
        0
      end
    end
  end
end
