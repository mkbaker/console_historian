# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConsoleHistorian::Truncator do
  let(:config) do
    ConsoleHistorian::Configuration.new.tap do |c|
      c.output_limit = 50
      c.max_tokens_to_submit = 100
    end
  end
  subject(:truncator) { described_class.new(config) }

  describe '#truncate_output' do
    it 'returns empty string for nil input' do
      expect(truncator.truncate_output(nil)).to eq('')
    end

    it 'returns empty string for empty input' do
      expect(truncator.truncate_output('')).to eq('')
    end

    context 'with generic output' do
      it 'passes through output within limit' do
        expect(truncator.truncate_output('short')).to eq('short')
      end

      it 'truncates output exceeding limit and appends notice' do
        long = 'a' * 100
        result = truncator.truncate_output(long)
        expect(result).to start_with('a' * 50)
        expect(result).to include('chars truncated')
      end
    end

    context 'with ActiveRecord output' do
      let(:ar_output) do
        "#<User id: 1, name: \"Alice\">,\n#<User id: 2, name: \"Bob\">"
      end

      it 'captures first record and appends truncation notice' do
        result = truncator.truncate_output(ar_output, 'ActiveRecord::Relation')
        expect(result).to include('#<User id: 1')
        expect(result).to include('more records truncated')
        expect(result).not_to include('Bob')
      end

      it 'detects AR output by return_class' do
        result = truncator.truncate_output(ar_output, 'ActiveRecord::Relation')
        expect(result).to include('more records truncated')
      end

      it 'returns single record without truncation notice' do
        single = '#<User id: 1, name: "Alice">'
        result = truncator.truncate_output(single, 'ActiveRecord::Base')
        expect(result).to eq(single)
      end

      it 'does not truncate mid-record when field value contains >' do
        output = '#<User id: 1, name: "a>b", email: "x@y.com">'
        result = truncator.truncate_output(output, 'ActiveRecord::Base')
        expect(result).to eq(output)
      end

      it 'handles nested object in field without premature truncation' do
        output = "#<Post id: 1, meta: #<Meta key: \"x\">, title: \"hi\">,\n#<Post id: 2, meta: #<Meta key: \"y\">, title: \"bye\">"
        result = truncator.truncate_output(output, 'ActiveRecord::Relation')
        expect(result).to include('#<Post id: 1')
        expect(result).to include('more records truncated')
        expect(result).not_to include('bye')
      end

      it 'correctly truncates collection with 3 records after the first' do
        records = (1..3).map { |i| "#<User id: #{i}, name: \"User#{i}\">" }.join(",\n")
        result = truncator.truncate_output(records, 'ActiveRecord::Relation')
        expect(result).to include('#<User id: 1')
        expect(result).to include('more records truncated')
        expect(result).not_to include('User2')
        expect(result).not_to include('User3')
      end
    end
  end

  describe '#pre_submission' do
    it 'returns entries unchanged when under budget' do
      entries = [
        { input: 'User.count', output: '42' },
        { input: 'Order.count', output: '10' }
      ]
      result = truncator.pre_submission(entries)
      expect(result[0][:output]).to eq('42')
    end

    it 'drops all outputs when over budget' do
      long_output = 'x' * 1000
      entries = Array.new(5) { { input: 'User.all', output: long_output } }
      result = truncator.pre_submission(entries)
      expect(result.all? { |e| e[:output] == '' }).to be(true)
    end

    it 'preserves inputs when dropping outputs' do
      long_output = 'x' * 1000
      entries = Array.new(5) { { input: 'User.all', output: long_output } }
      result = truncator.pre_submission(entries)
      expect(result.all? { |e| e[:input] == 'User.all' }).to be(true)
    end
  end
end
