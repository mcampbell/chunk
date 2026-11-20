# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes::Indentation do
  subject(:finder) { described_class.new }

  def lines_of(text)
    text.lines
  end

  it 'gives the parent key block for a change two levels deep in YAML' do
    lines = lines_of(<<~YAML)
      top: 1
      parent:
        child:
          leaf: 2
          other: 3
        sibling: 4
      next: 5
    YAML
    expect(finder.call(lines, 4)).to eq(3..5)
  end

  it 'includes the closing brace of a CSS rule' do
    lines = lines_of(<<~CSS)
      a { color: red; }
      .box {
        margin: 0;
        padding: 1px;
      }
      p { }
    CSS
    expect(finder.call(lines, 3)).to eq(2..5)
  end

  it 'includes the closing tag of an HTML element' do
    lines = lines_of(<<~HTML)
      <div>
        <ul>
          <li>one</li>
          <li>two</li>
        </ul>
        <p>x</p>
      </div>
    HTML
    expect(finder.call(lines, 3)).to eq(2..5)
  end

  it 'includes a closing line that starts with end' do
    expect(finder.call(lines_of("def a\n  x\n  y\nend\nz\n"), 2)).to eq(1..4)
  end

  # A YAML key such as "endpoint:" is the next sibling, not the end of the block.
  it 'leaves out a sibling line that only starts with the letters of end' do
    lines = lines_of("server:\n  port: 80\nendpoint: /api\n")

    expect(finder.call(lines, 2)).to eq(1..2)
  end

  it 'includes a closing bracket and a closing parenthesis' do
    expect(finder.call(lines_of("a = [\n  1,\n]\nb\n"), 2)).to eq(1..3)
    expect(finder.call(lines_of("a(\n  1,\n)\nb\n"), 2)).to eq(1..3)
  end

  it 'gives nil for a line at indentation level 0' do
    expect(finder.call(lines_of("a:\n  b\nc\n"), 3)).to be_nil
  end

  it 'finds the header and block with tab indentation' do
    expect(finder.call(lines_of("a:\n\tb:\n\t\tc\n  d\ne\n"), 3)).to eq(2..3)
  end

  # With a tab as 1 column, "\tc" would be less indented than "    b:" and give 1..3.
  it 'counts a leading tab as 8 columns' do
    expect(finder.call(lines_of("a:\n    b:\n\tc\n"), 3)).to eq(2..3)
  end

  it 'moves a tab after spaces to the next tab stop' do
    expect(finder.call(lines_of("a:\n        b: 1\n    \tc: 2\n"), 3)).to eq(1..3)
  end

  # The line above is in the block of x, the line below is at level 0, so only the rule below gives nil.
  it 'uses the next non-blank line for a blank changed line' do
    expect(finder.call(lines_of("x:\n  b: 1\n\ny:\n  c: 2\n"), 3)).to be_nil
  end

  it 'gives the block that a changed closing line closes' do
    json = lines_of("{\n  \"a\": {\n    \"x\": 1\n  },\n  \"b\": 2\n}\n")

    expect(finder.call(json, 4)).to eq(2..4)
  end

  it 'leaves out a sibling YAML key named end' do
    expect(finder.call(lines_of("server:\n  port: 80\nend: 1\n"), 2)).to eq(1..2)
  end

  it 'gives the parent key block for an item of a YAML list' do
    expect(finder.call(lines_of("items:\n  - one\n  - two\nnext: 1\n"), 3)).to eq(1..3)
  end

  it 'reads lines that end in a carriage return and a newline' do
    expect(finder.call(lines_of("a:\r\n  b: 1\r\nc: 2\r\n"), 2)).to eq(1..2)
  end

  it 'uses the nearest non-blank line above for a blank line at the end of the file' do
    expect(finder.call(lines_of("a:\n  b\n\n"), 3)).to eq(1..2)
  end

  it 'gives nil for a blank line between level 0 lines' do
    expect(finder.call(lines_of("a\n\nb\n"), 2)).to be_nil
  end

  it 'gives nil when no line above is less indented' do
    expect(finder.call(lines_of("  a\n  b\nc\n"), 2)).to be_nil
  end

  it 'leaves trailing blank lines out of the block' do
    expect(finder.call(lines_of("a:\n  b\n\n\nc\n"), 2)).to eq(1..2)
  end

  it 'runs the block to the end of the file' do
    expect(finder.call(lines_of("a:\n  b\n  c\n"), 2)).to eq(1..3)
  end

  it 'leaves trailing blank lines out of a block that runs to the end of the file' do
    expect(finder.call(lines_of("a:\n  b\n\n\n"), 2)).to eq(1..2)
  end

  it 'works with lines that have no newline' do
    expect(finder.call(['a:', '  b', 'c'], 2)).to eq(1..2)
  end

  # A large file can change on every line, and the hunk builder calls the finder once for each line.
  it 'finds the scope of each of 20,000 changed lines in one block in a short time' do
    lines = ["root:\n"] + (1..20_000).map { "  key#{it}: value\n" }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    (2..lines.size).each { finder.call(lines, it) }

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    expect(finder.call(lines, 20_001)).to eq(1..20_001)
  end
end
