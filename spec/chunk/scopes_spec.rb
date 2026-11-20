# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes do
  let(:lines) { Array.new(30) { |i| "l#{i + 1}\n" } }

  describe Chunk::Scopes::Fixed do
    subject(:fixed) { described_class.new(10) }

    it 'clamps at line 1' do
      expect(fixed.call(lines, 3)).to eq(1..13)
    end

    it 'clamps at the last line' do
      expect(fixed.call(lines, 30)).to eq(20..30)
    end

    it 'gives 10 lines each side in the middle' do
      expect(fixed.call(lines, 15)).to eq(5..25)
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

    it 'uses the default chain when no pattern matches' do
      expect(described_class.finder_for('a/x.rb', warnings).call(lines, 15)).to eq(5..25)
    end

    it 'falls to the next finder when one gives nil' do
      expect(finder([nil_finder, range_finder]).call(lines, 15)).to eq(2..4)
    end

    it 'gives n..n when every finder gives nil' do
      expect(finder([nil_finder]).call(lines, 15)).to eq(15..15)
    end

    it 'falls back to the default chain with one warning, even on two calls' do
      call = finder([bad_finder])
      expect(call.call(lines, 15)).to eq(5..25)
      expect(call.call(lines, 3)).to eq(1..13)
      expect(warnings).to eq(['a/x.rb: boom'])
    end
  end
end
