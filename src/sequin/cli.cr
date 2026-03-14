require "./commands/ledger_summary"
require "./commands/verify_chain"

module Sequin
  class CLI
    USAGE = <<-TEXT
    Usage:
      sequin verify:chain
      sequin ledger:summary [--top N] [--epochs N]
    TEXT

    def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
    end

    def run(args : Array(String), root : String = Dir.current) : Int32
      command = args[0]?
      return usage(1) unless command

      case command
      when "verify:chain"
        Commands::VerifyChain.new(@stdout, @stderr).call(root)
      when "ledger:summary"
        options = parse_ledger_summary_options(args[1..], @stderr)
        return 1 unless options
        Commands::LedgerSummary.new(@stdout).call(options, root)
      else
        @stderr.puts "Unknown command: #{command}"
        usage(1)
      end
    end

    private def usage(code : Int32) : Int32
      @stderr.puts USAGE
      code
    end

    private def parse_ledger_summary_options(args : Array(String), stderr : IO) : Commands::LedgerSummary::Options?
      top = 10
      epochs = 5
      index = 0

      while index < args.size
        flag = args[index]
        value = args[index + 1]?

        case flag
        when "--top"
          return option_error("#{flag} requires a value", stderr) unless value
          parsed = parse_int(flag, value, stderr)
          return nil unless parsed
          top = parsed
          index += 2
        when "--epochs"
          return option_error("#{flag} requires a value", stderr) unless value
          parsed = parse_int(flag, value, stderr)
          return nil unless parsed
          epochs = parsed
          index += 2
        else
          return option_error("Unknown option: #{flag}", stderr)
        end
      end

      Commands::LedgerSummary::Options.new(top: top, epochs: epochs)
    end

    private def parse_int(flag : String, value : String, stderr : IO) : Int32?
      parsed = value.to_i?
      return parsed if parsed
      option_error("#{flag} must be an integer, found #{value}", stderr)
    end

    private def option_error(message : String, stderr : IO)
      stderr.puts message
      nil
    end
  end
end
