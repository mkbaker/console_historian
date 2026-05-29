# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ConsoleHistorian
  module Providers
    class Anthropic
      API_URL = "https://api.anthropic.com/v1/messages"
      MODEL = "claude-3-5-haiku-20241022"

      def initialize
        @api_key = ENV["ANTHROPIC_API_KEY"]
      end

      def call(system_prompt, user_content)
        raise ProviderError, "ANTHROPIC_API_KEY not set" if @api_key.nil? || @api_key.empty?

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["x-api-key"] = @api_key
        request["anthropic-version"] = "2023-06-01"
        request.body = JSON.generate(
          model: MODEL,
          max_tokens: 2048,
          system: system_prompt,
          messages: [{ role: "user", content: user_content }]
        )

        response = http.request(request)
        raise ProviderError, "Anthropic API #{response.code}: #{response.body[0, 200]}" unless response.code.to_i == 200

        data = JSON.parse(response.body)
        data.dig("content", 0, "text") || raise(ProviderError, "Unexpected Anthropic response shape")
      end
    end
  end
end
