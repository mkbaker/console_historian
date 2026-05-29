# frozen_string_literal: true

module ConsoleHistorian
  class Configuration
    attr_accessor :ai_provider, :save_path, :output_limit, :max_tokens_to_submit, :redact

    def initialize
      @ai_provider = detect_provider
      @save_path = 'log/console_sessions'
      @output_limit = 500
      @max_tokens_to_submit = 8_000
      @redact = %i[
        password password_digest encrypted_password
        token auth_token access_token refresh_token bearer_token
        secret client_secret api_key api_secret private_key
        ssn credit_card
      ]
    end

    private

    def detect_provider
      return :anthropic if key?('ANTHROPIC_API_KEY')
      return :openai if key?('OPENAI_API_KEY')

      :none
    end

    def key?(name)
      val = ENV.fetch(name, nil)
      val && !val.empty?
    end
  end
end
