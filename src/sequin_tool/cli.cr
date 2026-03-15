require "option_parser"
require "./command"
require "./commands/apply_block"
require "./commands/ledger_summary"
require "./commands/mint_rewards"
require "./commands/score_epoch"
require "./commands/repo_lint"
require "./commands/tx_next_nonce"
require "./commands/tx_sign"
require "./commands/verify_chain"
require "./commands/verify_tx"
require "./commands/wallet_create"
require "./error_handling"
require "./fs"
require "./json_io"

module SequinTool
  class CLI
    getter commands : Array(Command)

    def initialize
      @commands = [] of Command
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
      when "repo:lint"
        Commands::RepoLint.new(stdout, stderr).call(root)
      when "verify:chain"
        Commands::VerifyChain.new(stdout, stderr).call(root)
      when "verify:tx"
        Commands::VerifyTx.new(stdout, stderr).call(root)
      when "wallet:create"
        github = parse_required_value(args[1..], "--github", stderr)
        return 1 unless github
        Commands::WalletCreate.new(stdout, stderr).call(github, root)
      when "tx:next-nonce"
        user = parse_required_value(args[1..], "--user", stderr)
        return 1 unless user
        Commands::TxNextNonce.new(stdout).call(user, root)
      when "tx:sign"
        tx_opts = parse_tx_sign_options(args[1..], stderr)
        return 1 unless tx_opts
        Commands::TxSign.new(stdout, stderr).call(
          tx_opts[:from],
          tx_opts[:to],
          tx_opts[:amount],
          tx_opts[:nonce],
          tx_opts[:memo],
          root
        )
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
      io.puts "  verify:tx             Validate pending tx and wallet state."
      io.puts "  wallet:create         Create a wallet keypair + wallet JSON."
      io.puts "  tx:next-nonce         Print next nonce for a user."
      io.puts "  tx:sign               Sign transfer tx JSON into tx/pending."
      io.puts "  repo:lint             Validate repository JSON integrity."
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
      when "verify:tx"
        stdout.puts "verify:tx - Validate pending txs and wallet state."
        stdout.puts
        stdout.puts "Validates tx schema fields, ids, nonce/balance progression, and secp256k1 signatures."
        return 0
      when "wallet:create"
        stdout.puts "wallet:create - Create local secp256k1 keypair + wallet JSON."
        stdout.puts
        stdout.puts "Options: --github <username>"
        return 0
      when "tx:next-nonce"
        stdout.puts "tx:next-nonce - Print next nonce for wallet user."
        stdout.puts
        stdout.puts "Options: --user <username>"
        return 0
      when "tx:sign"
        stdout.puts "tx:sign - Sign tx payload and write tx/pending/*.json."
        stdout.puts
        stdout.puts "Options: --from <user> --to <user> --amount <int> --nonce <int> [--memo <text>]"
        return 0
      when "repo:lint"
        stdout.puts "repo:lint - Validate repository JSON integrity."
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

    private def parse_required_value(args : Array(String), flag : String, stderr : IO) : String?
      index = args.index(flag)
      unless index
        stderr.puts "#{flag} is required"
        return nil
      end

      value = args[index + 1]?
      unless value
        stderr.puts "#{flag} requires a value"
        return nil
      end

      value
    end

    private def parse_tx_sign_options(args : Array(String), stderr : IO) : NamedTuple(from: String, to: String, amount: Int64, nonce: Int64, memo: String)?
      from = parse_required_value(args, "--from", stderr)
      to = parse_required_value(args, "--to", stderr)
      amount_s = parse_required_value(args, "--amount", stderr)
      nonce_s = parse_required_value(args, "--nonce", stderr)
      return nil unless from && to && amount_s && nonce_s

      amount = amount_s.to_i64?
      nonce = nonce_s.to_i64?
      unless amount
        stderr.puts "--amount must be integer"
        return nil
      end
      unless nonce
        stderr.puts "--nonce must be integer"
        return nil
      end

      memo = ""
      memo_idx = args.index("--memo")
      if memo_idx
        memo_val = args[memo_idx + 1]?
        unless memo_val
          stderr.puts "--memo requires a value"
          return nil
        end
        memo = memo_val
      end

      {from: from, to: to, amount: amount, nonce: nonce, memo: memo}
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
