module SequinTool
  class Command
    getter name : String
    getter summary : String
    getter details : String
    getter status_hint : String
    getter exit_code : Int32
    getter implementation_phase : String

    def initialize(
      @name : String,
      @summary : String,
      @details : String,
      @implementation_phase : String,
      @status_hint : String = "stub",
      @exit_code : Int32 = 1
    )
    end

    def help(io : IO)
      io.puts "#{name} - #{summary}"
      io.puts
      io.puts details
      io.puts
      io.puts "Status: #{status_hint}"
      io.puts "Implementation target: #{implementation_phase}"
    end

    def call(args : Array(String), stdout : IO, stderr : IO) : Int32
      if args.includes?("--help") || args.includes?("-h")
        help(stdout)
        return 0
      end

      stderr.puts %({"status":"#{status_hint}","command":"#{name}","message":"#{details}","implementation_target":"#{implementation_phase}"})
      exit_code
    end
  end
end
