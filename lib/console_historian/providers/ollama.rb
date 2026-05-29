# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module ConsoleHistorian
  module Providers
    class Ollama
      DEFAULT_HOST = 'http://localhost:11434'
      DEFAULT_MODEL = 'llama3'

      def initialize
        raw_host = ENV.fetch('OLLAMA_HOST', DEFAULT_HOST)
        uri = URI.parse(raw_host)
        unless %w[http https].include?(uri.scheme) && uri.host
          raise ArgumentError, "OLLAMA_HOST must be an http/https URL (got: #{raw_host.inspect})"
        end

        @host = raw_host
        @model = ENV.fetch('OLLAMA_MODEL', DEFAULT_MODEL)
      end

      def call(system_prompt, user_content)
        uri = URI("#{@host}/api/generate")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 120

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(
          model: @model,
          prompt: "#{system_prompt}\n\n#{user_content}",
          stream: false
        )

        response = http.request(request)
        raise ProviderError, "Ollama #{response.code}: #{response.body[0, 200]}" unless response.code.to_i == 200

        data = JSON.parse(response.body)
        data['response'] || raise(ProviderError, 'Unexpected Ollama response shape')
      end
    end
  end
end
