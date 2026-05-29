# frozen_string_literal: true

require "rails/railtie"

module ConsoleHistorian
  class Railtie < Rails::Railtie
    railtie_name :console_historian

    console do
      next unless Rails.env.development?

      require "console_historian"
      ConsoleHistorian::Recorder.start
    end

    rake_tasks do
      namespace :console_historian do
        desc "Install console_historian initializer and update .gitignore"
        task :install do
          require "rails/generators"
          require_relative "../generators/console_historian/install/install_generator"
          Rails::Generators.invoke("console_historian:install", [], { destination_root: Rails.root })
        end

        desc "List recent console sessions"
        task list: :environment do
          stems = ConsoleHistorian::Storage.new.list
          if stems.empty?
            puts "No sessions found in #{ConsoleHistorian.configuration.save_path}"
          else
            stems.each { |s| puts s }
          end
        end

        desc "Print a saved console session (pass stem as argument)"
        task :show, [:stem] => :environment do |_, args|
          stem = File.basename(args[:stem].to_s).gsub(/[^a-zA-Z0-9_\-]/, "")
          abort "Usage: rails console_historian:show[stem]" if stem.empty?

          content = ConsoleHistorian::Storage.new.load(stem)
          abort "Session '#{stem}' not found" if content.nil?

          puts content
        end

      end
    end
  end
end
