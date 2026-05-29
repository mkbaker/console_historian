# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe ConsoleHistorian::Storage do
  let(:tmpdir) { Dir.mktmpdir("console_historian_test") }
  let(:config) do
    ConsoleHistorian::Configuration.new.tap { |c| c.save_path = tmpdir }
  end
  subject(:storage) { described_class.new(config) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#save" do
    it "writes content to a file and returns the path" do
      path = storage.save("2026-01-01_12-00", "# Session")
      expect(File.read(path)).to eq("# Session")
    end

    it "creates save_path directory if missing" do
      nested = File.join(tmpdir, "nested", "sessions")
      config.save_path = nested
      storage.save("stem", "content")
      expect(Dir.exist?(nested)).to be(true)
    end
  end

  describe "#load" do
    it "returns file content by stem" do
      storage.save("my-session", "# Hello")
      expect(storage.load("my-session")).to eq("# Hello")
    end

    it "returns nil for missing stem" do
      expect(storage.load("nonexistent")).to be_nil
    end
  end

  describe "#list" do
    it "returns stems sorted newest first" do
      storage.save("2026-01-01_10-00", "a")
      storage.save("2026-01-02_10-00", "b")
      storage.save("2026-01-03_10-00", "c")
      stems = storage.list
      expect(stems.first).to eq("2026-01-03_10-00")
      expect(stems.last).to eq("2026-01-01_10-00")
    end

    it "returns empty array when no sessions saved" do
      expect(storage.list).to eq([])
    end
  end

  describe "#file_path" do
    it "returns path with .md extension" do
      expect(storage.file_path("my-stem")).to eq(File.join(tmpdir, "my-stem.md"))
    end
  end
end
