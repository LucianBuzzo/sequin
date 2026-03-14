require "json"

module SequinTool
  class CLIError < Exception
    getter exit_code : Int32
    getter details : Hash(String, String)?

    def initialize(message : String, @exit_code : Int32 = 1, @details : Hash(String, String)? = nil)
      super(message)
    end
  end

  module ErrorHandling
    def self.write_error(io : IO, message : String, exit_code : Int32, details : Hash(String, String)? = nil)
      payload = JSON.build do |json|
        json.object do
          json.field "status", "error"
          json.field "message", message
          json.field "exit_code", exit_code
          if details
            json.field "details" do
              json.object do
                details.keys.sort.each do |key|
                  json.field key, details[key]
                end
              end
            end
          end
        end
      end

      io.puts payload
    end

    def self.handle(io : IO, ex : CLIError) : Int32
      write_error(io, ex.message || ex.class.name, ex.exit_code, ex.details)
      ex.exit_code
    end

    def self.handle(io : IO, ex : Exception) : Int32
      write_error(io, ex.message || ex.class.name, 1)
      1
    end
  end
end
