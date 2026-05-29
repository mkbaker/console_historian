# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConsoleHistorian::Recorder do
  let(:storage) { instance_double(ConsoleHistorian::Storage, file_path: '/tmp/test.md', save: '/tmp/test.md') }
  let(:analyzer) { instance_double(ConsoleHistorian::Analyzer, analyze: '# Analysis') }

  before do
    allow(ConsoleHistorian::Storage).to receive(:new).and_return(storage)
    allow(ConsoleHistorian::Analyzer).to receive(:new).and_return(analyzer)
  end

  describe '#begin_session' do
    it 'sets @exit_registered after first call' do
      described_class.new.begin_session
      expect(described_class.instance_variable_get(:@exit_registered)).to be true
    end

    it 'current_recorder points to most recent recorder after multiple starts' do
      recorder1 = described_class.new
      recorder2 = described_class.new

      recorder1.begin_session
      recorder2.begin_session

      expect(ConsoleHistorian.current_recorder).to eq(recorder2)
    end
  end

  describe 'no duplicate writes on multi-start' do
    it 'finish is called exactly once on the active recorder' do
      described_class.new.begin_session
      described_class.new.begin_session

      expect(analyzer).to receive(:analyze).once

      ConsoleHistorian.current_recorder&.finish
    end
  end
end
