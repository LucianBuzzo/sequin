module SequinTool
  module FS
    def self.repo_root(start_dir : String = Dir.current) : String
      current = File.expand_path(start_dir)

      loop do
        return current if Dir.exists?(File.join(current, ".git")) || File.exists?(File.join(current, "MIGRATION_TODO.md"))

        parent = File.dirname(current)
        break if parent == current
        current = parent
      end

      raise CLIError.new("Could not determine repository root", exit_code: 2)
    end

    def self.safe_path(path : String, start_dir : String = Dir.current) : String
      root = repo_root(start_dir)
      expanded = File.expand_path(path, root)

      unless expanded == root || expanded.starts_with?("#{root}/")
        raise CLIError.new(
          "Refusing to access path outside repository root",
          exit_code: 2,
          details: {"path" => path}
        )
      end

      expanded
    end
  end
end
