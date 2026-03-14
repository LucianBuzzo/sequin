require "json"
require "./fs"

module SequinTool
  module JSONIO
    def self.read(path : String, start_dir : String = Dir.current) : JSON::Any
      expanded = FS.safe_path(path, start_dir)
      JSON.parse(File.read(expanded))
    rescue ex : File::NotFoundError
      raise CLIError.new("JSON file not found", exit_code: 2, details: {"path" => path})
    rescue ex : JSON::ParseException
      raise CLIError.new("Invalid JSON input", exit_code: 2, details: {"path" => path})
    end

    def self.write(path : String, value : JSON::Any, pretty : Bool = true, start_dir : String = Dir.current) : Nil
      expanded = FS.safe_path(path, start_dir)
      File.write(expanded, serialize(value, pretty: pretty))
    end

    def self.serialize(value : JSON::Any, pretty : Bool = true) : String
      output = String.build do |io|
        if pretty
          emit_pretty(value, io)
          io << '\n'
        else
          emit_canonical(value, io)
        end
      end

      output
    end

    private def self.emit_pretty(value : JSON::Any, io : IO)
      JSON.build(io, indent: "  ") do |json|
        emit_value(value, json, sort_keys: true)
      end
    end

    private def self.emit_canonical(value : JSON::Any, io : IO)
      JSON.build(io) do |json|
        emit_value(value, json, sort_keys: true)
      end
    end

    private def self.emit_value(value : JSON::Any, json : JSON::Builder, sort_keys : Bool)
      raw = value.raw

      case raw
      when Nil
        json.null
      when Bool
        json.bool(raw)
      when Int64
        json.number(raw)
      when Float64
        json.number(raw)
      when String
        json.string(raw)
      when Array(JSON::Any)
        json.array do
          raw.each do |item|
            emit_value(item, json, sort_keys: sort_keys)
          end
        end
      when Hash(String, JSON::Any)
        json.object do
          keys = sort_keys ? raw.keys.sort : raw.keys
          keys.each do |key|
            json.field key do
              emit_value(raw[key], json, sort_keys: sort_keys)
            end
          end
        end
      else
        raise CLIError.new("Unsupported JSON value type", exit_code: 2)
      end
    end
  end
end
