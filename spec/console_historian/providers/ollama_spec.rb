# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConsoleHistorian::Providers::Ollama do
  describe '#initialize' do
    context 'with default host' do
      it 'accepts default localhost URL' do
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'with valid OLLAMA_HOST' do
      it 'accepts http localhost' do
        stub_const('ENV', ENV.to_h.merge('OLLAMA_HOST' => 'http://localhost:11434'))
        expect { described_class.new }.not_to raise_error
      end

      it 'accepts https LAN host' do
        stub_const('ENV', ENV.to_h.merge('OLLAMA_HOST' => 'https://my-ollama.internal:11434'))
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'with invalid OLLAMA_HOST' do
      it 'raises ArgumentError for ftp scheme' do
        stub_const('ENV', ENV.to_h.merge('OLLAMA_HOST' => 'ftp://evil.com'))
        expect { described_class.new }.to raise_error(ArgumentError, %r{OLLAMA_HOST must be an http/https URL})
      end

      it 'raises ArgumentError for non-URL string' do
        stub_const('ENV', ENV.to_h.merge('OLLAMA_HOST' => 'evil.com'))
        expect { described_class.new }.to raise_error(ArgumentError, %r{OLLAMA_HOST must be an http/https URL})
      end

      it 'raises ArgumentError for empty string' do
        stub_const('ENV', ENV.to_h.merge('OLLAMA_HOST' => ''))
        expect { described_class.new }.to raise_error(ArgumentError, %r{OLLAMA_HOST must be an http/https URL})
      end
    end
  end
end
