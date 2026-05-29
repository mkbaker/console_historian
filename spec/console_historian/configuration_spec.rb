# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConsoleHistorian::Configuration do
  subject(:config) { described_class.new }

  around do |example|
    orig_anthropic = ENV.delete('ANTHROPIC_API_KEY')
    orig_openai = ENV.delete('OPENAI_API_KEY')
    orig_ollama = ENV.delete('OLLAMA_HOST')
    example.run
  ensure
    ENV['ANTHROPIC_API_KEY'] = orig_anthropic if orig_anthropic
    ENV['OPENAI_API_KEY'] = orig_openai if orig_openai
    ENV['OLLAMA_HOST'] = orig_ollama if orig_ollama
  end

  describe 'defaults' do
    it 'defaults save_path to log/console_sessions' do
      expect(config.save_path).to eq('log/console_sessions')
    end

    it 'defaults output_limit to 500' do
      expect(config.output_limit).to eq(500)
    end

    it 'defaults max_tokens_to_submit to 8_000' do
      expect(config.max_tokens_to_submit).to eq(8_000)
    end

    it 'includes standard sensitive field names in redact' do
      expect(config.redact).to include(:password, :token, :secret, :api_key)
    end

    it 'defaults ai_provider to :none when no API keys set' do
      expect(config.ai_provider).to eq(:none)
    end
  end

  describe 'provider detection' do
    it 'detects :anthropic when ANTHROPIC_API_KEY present' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-test'
      expect(described_class.new.ai_provider).to eq(:anthropic)
    end

    it 'detects :openai when OPENAI_API_KEY present and no anthropic key' do
      ENV['OPENAI_API_KEY'] = 'sk-test'
      expect(described_class.new.ai_provider).to eq(:openai)
    end

    it 'prefers anthropic over openai when both present' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-test'
      ENV['OPENAI_API_KEY'] = 'sk-test'
      expect(described_class.new.ai_provider).to eq(:anthropic)
    end

    it 'detects :ollama when OLLAMA_HOST present and no API keys set' do
      ENV['OLLAMA_HOST'] = 'http://localhost:11434'
      expect(described_class.new.ai_provider).to eq(:ollama)
    end

    it 'prefers anthropic over ollama when both present' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-test'
      ENV['OLLAMA_HOST'] = 'http://localhost:11434'
      expect(described_class.new.ai_provider).to eq(:anthropic)
    end
  end

  describe 'configuration via ConsoleHistorian.configure' do
    it 'yields config and applies changes' do
      ConsoleHistorian.configure do |c|
        c.ai_provider = :ollama
        c.output_limit = 1000
      end
      expect(ConsoleHistorian.configuration.ai_provider).to eq(:ollama)
      expect(ConsoleHistorian.configuration.output_limit).to eq(1000)
    end
  end
end
