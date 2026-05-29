# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConsoleHistorian::Providers::Anthropic do
  around do |example|
    orig = ENV.delete('ANTHROPIC_API_KEY')
    example.run
  ensure
    ENV['ANTHROPIC_API_KEY'] = orig if orig
  end

  describe '#initialize' do
    it 'raises ProviderError when key missing' do
      expect { described_class.new }.to raise_error(ConsoleHistorian::ProviderError, /ANTHROPIC_API_KEY not set/)
    end

    it 'raises ProviderError when key empty' do
      ENV['ANTHROPIC_API_KEY'] = ''
      expect { described_class.new }.to raise_error(ConsoleHistorian::ProviderError, /ANTHROPIC_API_KEY not set/)
    end

    it 'succeeds with key present' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-test'
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#call' do
    subject(:provider) do
      ENV['ANTHROPIC_API_KEY'] = 'sk-test'
      described_class.new
    end

    let(:http) { instance_double(Net::HTTP) }
    let(:request) { instance_double(Net::HTTP::Post) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(Net::HTTP::Post).to receive(:new).and_return(request)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=)
    end

    context 'on success' do
      let(:response_body) do
        JSON.generate({ 'content' => [{ 'type' => 'text', 'text' => 'runbook here' }] })
      end
      let(:response) { instance_double(Net::HTTPSuccess, code: '200', body: response_body) }

      before { allow(http).to receive(:request).and_return(response) }

      it 'returns text from response' do
        expect(provider.call('system', 'user')).to eq('runbook here')
      end

      it 'sets x-api-key header' do
        provider.call('system', 'user')
        expect(request).to have_received(:[]=).with('x-api-key', 'sk-test')
      end

      it 'sets anthropic-version header' do
        provider.call('system', 'user')
        expect(request).to have_received(:[]=).with('anthropic-version', '2023-06-01')
      end
    end

    context 'on non-200 response' do
      let(:response) { instance_double(Net::HTTPClientError, code: '401', body: 'Unauthorized') }

      before { allow(http).to receive(:request).and_return(response) }

      it 'raises ProviderError with status code' do
        expect { provider.call('system', 'user') }.to raise_error(ConsoleHistorian::ProviderError, /Anthropic API 401/)
      end
    end

    context 'on unexpected response shape' do
      let(:response_body) { JSON.generate({ 'content' => [] }) }
      let(:response) { instance_double(Net::HTTPSuccess, code: '200', body: response_body) }

      before { allow(http).to receive(:request).and_return(response) }

      it 'raises ProviderError' do
        expect do
          provider.call('system', 'user')
        end.to raise_error(ConsoleHistorian::ProviderError, /Unexpected Anthropic/)
      end
    end
  end
end
