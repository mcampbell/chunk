# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes do
  let(:lines) { Array.new(30) { |i| "l#{i + 1}\n" } }

  describe Chunk::Scopes::Fixed do
    subject(:fixed) { described_class.new(10) }

    # Line numbers are primes chosen on purpose, so an off-by-one shows in the result.
    it 'stops at the first line of the file' do
      expect(fixed.call(lines, 3)).to eq(1..13)
    end

    it 'stops at the last line of the file' do
      expect(fixed.call(lines, 29)).to eq(19..30)
    end

    it 'keeps 10 lines on each side in the middle of the file' do
      expect(fixed.call(lines, 17)).to eq(7..27)
    end

    it 'keeps the whole file when the file is shorter than the scope' do
      expect(fixed.call(lines.first(7), 3)).to eq(1..7)
    end
  end

  describe '.finder_for' do
    let(:warnings) { [] }
    let(:nil_finder) { ->(_lines, _line) {} }
    let(:range_finder) { ->(_lines, _line) { 2..4 } }
    let(:bad_finder) { ->(_lines, _line) { raise Chunk::Scopes::Unreadable, 'boom' } }

    def finder(chain)
      described_class.finder_for('a/x.rb', warnings, chains: { '*.rb' => chain })
    end

    describe 'the default chain' do
      let(:yaml) { "top:\n  child:\n    leaf: 1\n  other: 2\nnext: 3\n\nlast: 4\n".lines }

      it 'gives the indentation block of a changed line in a YAML file' do
        expect(described_class.finder_for('c.yml', warnings).call(yaml, 3)).to eq(2..3)
      end

      it 'gives the paragraph of a changed line at indentation level 0' do
        expect(described_class.finder_for('c.yml', warnings).call(yaml, 5)).to eq(1..5)
      end
    end

    it 'falls to the next finder when one gives nil' do
      expect(finder([nil_finder, range_finder]).call(lines, 15)).to eq(2..4)
    end

    it 'keeps only the changed line when every finder gives nil' do
      expect(finder([nil_finder]).call(lines, 15)).to eq(15..15)
    end

    it 'falls back to the default chain with one warning, even on two calls' do
      call = finder([bad_finder])
      # The lines have no indentation and no blank line, so the default chain gives the whole file.
      expect(call.call(lines, 17)).to eq(1..30)
      expect(call.call(lines, 3)).to eq(1..30)
      expect(warnings).to eq(['a/x.rb: boom'])
    end
  end
end
