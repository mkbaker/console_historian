# frozen_string_literal: true

require "spec_helper"

RSpec.describe ConsoleHistorian::Redactor do
  subject(:redactor) { described_class.new(%i[password token api_key]) }

  describe "#redact" do
    it "redacts hash-rocket string value" do
      input = 'User.find_by(password: "secret123")'
      expect(redactor.redact(input)).to include("[REDACTED]")
      expect(redactor.redact(input)).not_to include("secret123")
    end

    it "redacts symbol key value" do
      input = "{ api_key: \"abc123\" }"
      result = redactor.redact(input)
      expect(result).to include("[REDACTED]")
      expect(result).not_to include("abc123")
    end

    it "leaves unrelated keys untouched" do
      input = "User.where(email: \"test@example.com\")"
      expect(redactor.redact(input)).to eq(input)
    end

    it "returns non-string input unchanged" do
      expect(redactor.redact(nil)).to be_nil
      expect(redactor.redact(42)).to eq(42)
    end

    it "is case-insensitive for pattern matching" do
      input = 'update(PASSWORD: "secret")'
      result = redactor.redact(input)
      expect(result).to include("[REDACTED]")
    end
  end

  describe "#redact_entries" do
    let(:entries) do
      [
        { input: 'find_by(token: "abc")', output: "found user", timestamp: "t1" },
        { input: "User.count", output: "42", timestamp: "t2" }
      ]
    end

    it "redacts input and output in each entry" do
      result = redactor.redact_entries(entries)
      expect(result[0][:input]).to include("[REDACTED]")
      expect(result[1][:input]).to eq("User.count")
    end

    it "preserves all other entry keys" do
      result = redactor.redact_entries(entries)
      expect(result[0][:timestamp]).to eq("t1")
    end
  end
end
