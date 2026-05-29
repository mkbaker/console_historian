# frozen_string_literal: true

require "rails/generators"

module ConsoleHistorian
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/console_historian.rb"
      end

      def update_gitignore
        gitignore_path = File.join(destination_root, ".gitignore")
        return create_gitignore_entry(gitignore_path) unless File.exist?(gitignore_path)

        content = File.read(gitignore_path)
        if content.match?(%r{^log/$|^log/\*})
          say "  log/ already ignored — skipping log/console_sessions/ entry", :yellow
        elsif content.include?("log/console_sessions/")
          say "  log/console_sessions/ already in .gitignore — skipping", :yellow
        else
          append_to_file ".gitignore", "\n# console_historian session files\nlog/console_sessions/\n"
        end
      end

      private

      def create_gitignore_entry(path)
        create_file ".gitignore", "# console_historian session files\nlog/console_sessions/\n"
      end
    end
  end
end
