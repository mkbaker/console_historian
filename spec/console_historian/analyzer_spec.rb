# frozen_string_literal: true

require "spec_helper"

RSpec.describe ConsoleHistorian::Analyzer do
  subject(:analyzer) { described_class.new(config) }

  let(:config) do
    ConsoleHistorian::Configuration.new.tap do |c|
      c.ai_provider = :anthropic
    end
  end

  let(:entries) do
    Array.new(5) do |i|
      { input: "User.find(#{i + 1})", output: "#<User id: #{i + 1}>", timestamp: "2026-05-29T14:0#{i}:00" }
    end
  end

  describe "#analyze" do
    context "with fewer than 3 commands" do
      it "returns nil" do
        expect(analyzer.analyze(entries.first(2))).to be_nil
      end
    end

    context "with provider :none" do
      let(:config) { ConsoleHistorian::Configuration.new.tap { |c| c.ai_provider = :none } }

      it "returns nil" do
        expect(analyzer.analyze(entries)).to be_nil
      end
    end

    context "with no API key set" do
      around do |example|
        orig = ENV.delete("ANTHROPIC_API_KEY")
        example.run
      ensure
        ENV["ANTHROPIC_API_KEY"] = orig if orig
      end

      it "returns nil" do
        expect(analyzer.analyze(entries)).to be_nil
      end
    end

    context "when provider raises ProviderError" do
      before do
        ENV["ANTHROPIC_API_KEY"] = "sk-test"
        fake_provider = instance_double(ConsoleHistorian::Providers::Anthropic)
        allow(fake_provider).to receive(:call).and_raise(ConsoleHistorian::ProviderError, "timeout")
        allow(ConsoleHistorian::Providers::Anthropic).to receive(:new).and_return(fake_provider)
      end

      after { ENV.delete("ANTHROPIC_API_KEY") }

      it "returns nil instead of raising" do
        expect(analyzer.analyze(entries)).to be_nil
      end
    end

    context "with valid provider and entries" do
      before do
        ENV["ANTHROPIC_API_KEY"] = "sk-test"
        fake_provider = instance_double(ConsoleHistorian::Providers::Anthropic)
        allow(fake_provider).to receive(:call).and_return("# Console Session — 2026-05-29")
        allow(ConsoleHistorian::Providers::Anthropic).to receive(:new).and_return(fake_provider)
      end

      after { ENV.delete("ANTHROPIC_API_KEY") }

      it "returns the LLM response text" do
        result = analyzer.analyze(entries)
        expect(result).to eq("# Console Session — 2026-05-29")
      end

      it "calls redactor on entries before submission" do
        redactor = instance_double(ConsoleHistorian::Redactor)
        allow(ConsoleHistorian::Redactor).to receive(:new).and_return(redactor)
        allow(redactor).to receive(:redact_entries).and_return(entries)
        allow(ConsoleHistorian::Truncator.new).to receive(:pre_submission).and_return(entries)

        analyzer.analyze(entries)
        expect(redactor).to have_received(:redact_entries).with(entries)
      end
    end
  end
end
