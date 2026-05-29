# frozen_string_literal: true

require "open3"

module ConsoleHistorian
  module Providers
    class ClaudeCLI
      DEFAULT_MODEL = "haiku"
      BINARY = File.expand_path("~/.claude/local/claude")

      def initialize(model: nil)
        @model = model || DEFAULT_MODEL
        raise ProviderError, "claude CLI not found at #{BINARY}" unless File.exist?(BINARY)
      end

      def self.available?
        File.exist?(BINARY)
      end

      # Shared provider interface: call(system_prompt, user_content) → String
      def call(system_prompt, user_content)
        prompt = "#{system_prompt}\n\n#{user_content}"
        stdout, stderr, status = Open3.capture3(
          BINARY, "-p", prompt, "--model", @model, "--no-session-persistence"
        )
        raise ProviderError, "claude CLI failed: #{stderr.strip[0, 200]}" unless status.success?

        stdout.strip
      end
    end
  end
end
