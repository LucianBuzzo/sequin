require "option_parser"
require "./command"
require "./commands/apply_block"
require "./commands/ledger_summary"
require "./commands/mint_rewards"
require "./commands/score_epoch"
require "./commands/verify_chain"
require "./error_handling"
require "./fs"
require "./json_io"

module SequinTool
  class CLI
    getter commands : Array(Command)

    def initialize
      @commands = [
        Command.new("verify:tx", "Verify a pending transaction payload.", "Command stub only. Transaction verification will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("wallet:create", "Create a wallet keypair and public registration payload.", "Command stub only. Wallet creation will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("tx:next-nonce", "Compute the next nonce for a wallet.", "Command stub only. Nonce lookup will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("tx:sign", "Sign a transfer payload.", "Command stub only. Transaction signing will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("repo:lint", "Run repository integrity checks for GitHub-backed state.", "Command stub only. Repo linting will be filled in during CLI migration.", "Phase 3", exit_code: 1),
      ]
    end

    def run(args : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR, root : String = Dir.current) : Int32
      if args.empty? || help_flag?(args[0])
        write_help(stdout)
        return 0
      end

      if args[0] == "help"
        return help_for(args[1]?, stdout, stderr)
      end

      case args[0]
      when "verify:chain"
        Commands::VerifyChain.new(stdout, stderr).call(root)
      when "ledger:summary"
        options = parse_ledger_summary_options(args[1..], stderr)
        return 1 unless options
        Commands::LedgerSummary.new(stdout).call(options, root)
      when "ledger:apply-block"
        Commands::ApplyBlock.new(stdout, stderr).call(root)
      when "rewards:mint"
        date = parse_date_option(args[1..], stderr)
        return 1 if date == :error
        Commands::MintRewards.new(stdout, stderr).call(date.as(String?), root)
      when "rewards:score-epoch"
        date = parse_date_option(args[1..], stderr)
        return 1 if date == :error
        Commands::ScoreEpoch.new(stdout, stderr).call(date.as(String?), root)
      else
        command = commands.find { |item| item.name == args[0] }
        unless command
          raise CLIError.new(
            "Unknown command",
            exit_code: 2,
            details: {"command" => args[0]}
          )
        end

        command.call(args[1..], stdout, stderr)
      end
    rescue ex : CLIError
      ErrorHandling.handle(stderr, ex)
    rescue ex
      ErrorHandling.handle(stderr, ex)
    end

    def write_help(io : IO)
      io.puts "sequin_tool - unified Crystal CLI for GitHub-backed Sequin"
      io.puts
      io.puts "Usage:"
      io.puts "  sequin_tool <command> [options]"
      io.puts "  sequin_tool help <command>"
      io.puts
      io.puts "Implemented commands:"
      io.puts "  verify:chain          Verify canonical ledger chain state."
      io.puts "  ledger:summary        Print a ledger summary report."
      io.puts "  ledger:apply-block    Apply pending transactions into ledger state."
      io.puts "  rewards:mint          Mint a reward manifest into ledger state."
      io.puts "  rewards:score-epoch   Score GitHub PR activity into reward manifest."
      io.puts
      io.puts "Stub commands:"
      commands.each do |command|
        io.puts "  #{command.name.ljust(20)} #{command.summary}"
      end
    end

    private def help_flag?(arg : String) : Bool
      arg == "--help" || arg == "-h"
    end

    private def help_for(name : String?, stdout : IO, stderr : IO) : Int32
      unless name
        write_help(stdout)
        return 0
      end

      case name
      when "verify:chain"
        stdout.puts "verify:chain - Verify canonical ledger chain state."
        stdout.puts
        stdout.puts "Validates block heights, prevHash linkage, and meta.lastHeight."
        return 0
      when "ledger:summary"
        stdout.puts "ledger:summary - Print ledger summary."
        stdout.puts
        stdout.puts "Options: --top N --epochs N"
        return 0
      when "ledger:apply-block"
        stdout.puts "ledger:apply-block - Apply pending tx files into a new block."
        return 0
      when "rewards:mint"
        stdout.puts "rewards:mint - Mint reward manifest into ledger state."
        stdout.puts
        stdout.puts "Options: --date YYYY-MM-DD"
        return 0
      when "rewards:score-epoch"
        stdout.puts "rewards:score-epoch - Score GitHub PR activity into reward manifest."
        stdout.puts
        stdout.puts "Options: --date YYYY-MM-DD"
        return 0
      end

      command = commands.find { |item| item.name == name }
      unless command
        raise CLIError.new("Unknown command", exit_code: 2, details: {"command" => name})
      end

      command.help(stdout)
      0
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

    private def parse_date_option(args : Array(String), stderr : IO) : String | Symbol | Nil
      return nil if args.empty?
      return :error if args.size != 2 || args[0] != "--date"

      date = args[1]
      unless /^\d{4}-\d{2}-\d{2}$/.matches?(date)
        stderr.puts "--date must be YYYY-MM-DD"
        return :error
      end

      date
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
