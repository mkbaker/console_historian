# frozen_string_literal: true

require "fileutils"

module ConsoleHistorian
  class Storage
    def initialize(config = nil)
      @config = config || ConsoleHistorian.configuration
    end

    def save(stem, content)
      FileUtils.mkdir_p(@config.save_path)
      path = file_path(stem)
      File.write(path, content)
      path
    end

    def load(stem)
      path = file_path(stem)
      return nil unless File.exist?(path)

      File.read(path)
    end

    def list
      Dir.glob(File.join(@config.save_path, "*.md"))
         .sort
         .reverse
         .map { |f| File.basename(f, ".md") }
    end

    def file_path(stem)
      s = stem.to_s
      raise ArgumentError, "Invalid session stem: #{stem.inspect}" if s.empty? || s =~ /[\/\\.]/

      safe = s.gsub(/[^a-zA-Z0-9_\-]/, "")
      raise ArgumentError, "Invalid session stem: #{stem.inspect}" if safe.empty?

      File.join(@config.save_path, "#{safe}.md")
    end
  end
end
