require "./command"
require "./error_handling"
require "./fs"
require "./json_io"

module SequinTool
  class CLI
    getter commands : Array(Command)

    def initialize
      @commands = [
        Command.new("verify:chain", "Verify canonical ledger chain state.", "Command stub only. Chain verification will be ported in Phase 3.", "Phase 3", exit_code: 1),
        Command.new("verify:tx", "Verify a pending transaction payload.", "Command stub only. Transaction verification will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("ledger:apply-block", "Apply pending transactions into ledger state.", "Command stub only. Block application will be ported in Phase 3.", "Phase 3", exit_code: 1),
        Command.new("rewards:score-epoch", "Score GitHub activity for a reward epoch.", "Command stub only. Epoch scoring will be ported in Phase 4.", "Phase 4", exit_code: 1),
        Command.new("rewards:mint", "Mint a reward manifest into ledger state.", "Command stub only. Reward minting will be ported in Phase 3.", "Phase 3", exit_code: 1),
        Command.new("ledger:summary", "Print a ledger summary report.", "Command stub only. Ledger reporting will be ported in Phase 3.", "Phase 3", exit_code: 1),
        Command.new("wallet:create", "Create a wallet keypair and public registration payload.", "Command stub only. Wallet creation will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("tx:next-nonce", "Compute the next nonce for a wallet.", "Command stub only. Nonce lookup will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("tx:sign", "Sign a transfer payload.", "Command stub only. Transaction signing will be ported in Phase 5.", "Phase 5", exit_code: 1),
        Command.new("repo:lint", "Run repository integrity checks for GitHub-backed state.", "Command stub only. Repo linting will be filled in during CLI migration.", "Phase 3", exit_code: 1),
      ]
    end

    def run(args : Array(String), stdout : IO = STDOUT, stderr : IO = STDERR) : Int32
      if args.empty? || help_flag?(args[0])
        write_help(stdout)
        return 0
      end

      if args[0] == "help"
        return help_for(args[1]?, stdout, stderr)
      end

      command = commands.find { |item| item.name == args[0] }
      unless command
        raise CLIError.new(
          "Unknown command",
          exit_code: 2,
          details: {"command" => args[0]}
        )
      end

      command.call(args[1..], stdout, stderr)
    rescue ex : CLIError
      ErrorHandling.handle(stderr, ex)
    rescue ex
      ErrorHandling.handle(stderr, ex)
    end

    def write_help(io : IO)
      io.puts "sequin_tool - unified Crystal CLI skeleton for GitHub-backed Sequin"
      io.puts
      io.puts "Usage:"
      io.puts "  sequin_tool <command> [options]"
      io.puts "  sequin_tool help <command>"
      io.puts
      io.puts "Available commands:"

      commands.each do |command|
        io.puts "  #{command.name.ljust(20)} #{command.summary}"
      end

      io.puts
      io.puts "Each command is currently a Crystal scaffold stub. Use '<command> --help' for status details."
    end

    private def help_flag?(arg : String) : Bool
      arg == "--help" || arg == "-h"
    end

    private def help_for(name : String?, stdout : IO, stderr : IO) : Int32
      unless name
        write_help(stdout)
        return 0
      end

      command = commands.find { |item| item.name == name }
      unless command
        raise CLIError.new("Unknown command", exit_code: 2, details: {"command" => name})
      end

      command.help(stdout)
      0
    end
  end
end
