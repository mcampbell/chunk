# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes::Paragraph do
  subject(:paragraph) { described_class.new }

  # Paragraphs of 3, 4, and 4 lines, so an off-by-one at either end shows in the result.
  let(:lines) { %W[a\n b\n c\n \n d\n e\n f\n g\n \n h\n i\n j\n k\n] }

  it 'starts at the first line of the file for the first paragraph' do
    expect(paragraph.call(lines, 2)).to eq(1..3)
  end

  it 'excludes the blank lines around a middle paragraph' do
    expect(paragraph.call(lines, 5)).to eq(5..8)
  end

  it 'stops at the last line of the file for the last paragraph' do
    expect(paragraph.call(lines, 11)).to eq(10..13)
  end

  it 'gives the whole file when no line is blank' do
    expect(paragraph.call(lines.reject { |l| l == "\n" }, 7)).to eq(1..11)
  end

  it 'gives the paragraph below for a blank changed line' do
    expect(paragraph.call(lines, 4)).to eq(5..8)
  end

  it 'counts a whitespace-only line as blank' do
    spaced = lines.dup
    spaced[3] = " \t\n"
    expect(paragraph.call(spaced, 3)).to eq(1..3)
  end

  it 'gives the paragraph above for a blank changed line at the end of the file' do
    expect(paragraph.call(lines + %W[\n \n], 15)).to eq(10..13)
  end

  it 'gives nil when every line is blank' do
    expect(paragraph.call(%W[\n \n], 2)).to be_nil
  end

  # A large file can change on every line, and the hunk builder calls the finder once for each line.
  it 'finds the scope of each of 20,000 changed lines in one block in a short time' do
    lines = (1..20_000).map { "key#{it}: value\n" }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    (2..lines.size).each { paragraph.call(lines, it) }

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    expect(paragraph.call(lines, 20_000)).to eq(1..20_000)
  end
end
