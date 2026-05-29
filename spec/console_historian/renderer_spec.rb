# frozen_string_literal: true

require "spec_helper"

RSpec.describe ConsoleHistorian::Renderer do
  subject(:renderer) { described_class.new }

  describe "#render_llm_response" do
    it "returns stripped response text" do
      expect(renderer.render_llm_response("stem", "  # Hello\n")).to eq("# Hello")
    end

    it "handles nil response gracefully" do
      expect(renderer.render_llm_response("stem", nil)).to eq("")
    end
  end

  describe "#render_fallback" do
    let(:entries) do
      [
        { input: "User.count", output: "42" },
        { input: "Order.where(status: :pending).count", output: "7" }
      ]
    end
    let(:metadata) { { started_at: "2026-05-29 14:14", git_sha: "abc1234", duration_minutes: 5 } }

    it "includes session header with started_at" do
      result = renderer.render_fallback("stem", entries, metadata)
      expect(result).to include("# Console Session — 2026-05-29 14:14")
    end

    it "includes git SHA" do
      result = renderer.render_fallback("stem", entries, metadata)
      expect(result).to include("abc1234")
    end

    it "includes command count" do
      result = renderer.render_fallback("stem", entries, metadata)
      expect(result).to include("**Commands:** 2")
    end

    it "includes all command inputs" do
      result = renderer.render_fallback("stem", entries, metadata)
      expect(result).to include("User.count")
      expect(result).to include("Order.where")
    end

    it "wraps commands in a ruby code block" do
      result = renderer.render_fallback("stem", entries, metadata)
      expect(result).to include("```ruby")
      expect(result).to include("```")
    end

    it "uses stem as fallback when no started_at" do
      result = renderer.render_fallback("my-stem", entries, {})
      expect(result).to include("my-stem")
    end
  end
end
