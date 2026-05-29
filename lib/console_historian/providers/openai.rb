# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module ConsoleHistorian
  module Providers
    class OpenAI
      API_URL = "https://api.openai.com/v1/chat/completions"
      MODEL = "gpt-4o"

      def initialize
        @api_key = ENV["OPENAI_API_KEY"]
      end

      def call(system_prompt, user_content)
        raise ProviderError, "OPENAI_API_KEY not set" if @api_key.nil? || @api_key.empty?

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri.path)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@api_key}"
        request.body = JSON.generate(
          model: MODEL,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_content }
          ]
        )

        response = http.request(request)
        raise ProviderError, "OpenAI API #{response.code}: #{response.body[0, 200]}" unless response.code.to_i == 200

        data = JSON.parse(response.body)
        data.dig("choices", 0, "message", "content") || raise(ProviderError, "Unexpected OpenAI response shape")
      end
    end
  end
end
