# frozen_string_literal: true

require_relative "console_historian/version"
require_relative "console_historian/configuration"
require_relative "console_historian/truncator"
require_relative "console_historian/redactor"
require_relative "console_historian/storage"
require_relative "console_historian/renderer"
require_relative "console_historian/analyzer"
require_relative "console_historian/recorder"
require_relative "console_historian/providers/anthropic"
require_relative "console_historian/providers/openai"
require_relative "console_historian/providers/ollama"
require_relative "console_historian/providers/claude_cli"

module ConsoleHistorian
  class ProviderError < StandardError; end

  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end

    def session_id
      @session_id
    end

    def current_recorder
      @current_recorder
    end
  end
end

require_relative "console_historian/railtie" if defined?(Rails::Railtie)
