# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Chunk::Scopes::Ruby do
  subject(:finder) { described_class.new }

  let(:source) do
    <<~RUBY
      require 'json'

      class Foo
        def a
          [1].each do |x|
            puts x
          end
        end

        def b
          2
        end

        def c = 3
      end
    RUBY
  end

  def find(code, line_number)
    finder.call(code.lines, line_number)
  end

  it 'gives only the method for a line in a method' do
    expect(find(source, 11)).to eq(10..12)
  end

  it 'gives the method for a line in a do block inside a method' do
    expect(find(source, 6)).to eq(4..8)
  end

  it 'gives the class for a line between two methods' do
    expect(find(source, 9)).to eq(3..15)
  end

  it 'gives nil for a require line' do
    expect(find(source, 1)).to be_nil
  end

  it 'gives the endless method for a line in an endless def' do
    expect(find(source, 14)).to eq(14..14)
  end

  it 'gives the method for a nested method in class << self' do
    code = <<~RUBY
      class Foo
        class << self
          def build
            new
          end
        end
      end
    RUBY
    expect(find(code, 4)).to eq(3..5)
  end

  it 'gives the whole method for a line in a heredoc inside a method' do
    code = <<~RUBY
      def text
        <<~TEXT
          hello
        TEXT
      end
    RUBY
    expect(find(code, 3)).to eq(1..5)
  end

  it 'raises Unreadable for a syntax error' do
    expect { find("def a\n", 1) }.to raise_error(Chunk::Scopes::Unreadable)
  end

  it 'parses the same lines array one time' do
    lines = source.lines
    allow(Prism).to receive(:parse).and_call_original
    2.times { |i| finder.call(lines, i + 1) }
    expect(Prism).to have_received(:parse).once
  end

  # The hunk builder calls with the old file (deleted lines) and the new file (added lines) in turn.
  it 'parses the old file and the new file once each, when calls take turns' do
    old_lines = source.lines
    new_lines = source.lines
    allow(Prism).to receive(:parse).and_call_original

    3.times { [old_lines, new_lines].each { finder.call(it, 11) } }

    expect(Prism).to have_received(:parse).twice
  end

  it 'gives the inner class for a line outside each method in a nested class' do
    lines = "module M\n  class A\n    X = 1\n  end\nend\n".lines

    expect(finder.call(lines, 3)).to eq(2..4)
  end

  it 'gives the class << self block for a line outside each method in it' do
    lines = "class A\n  class << self\n    attr_reader :x\n  end\nend\n".lines

    expect(finder.call(lines, 3)).to eq(2..4)
  end

  it 'gives the method for a line in a private def' do
    lines = "class A\n  private def x\n    1\n  end\nend\n".lines

    expect(finder.call(lines, 3)).to eq(2..4)
  end

  it 'gives nil for a line in the data after __END__' do
    lines = "def x\n  1\nend\n__END__\ndata\n".lines

    expect(finder.call(lines, 5)).to be_nil
  end

  # The hunk builder calls once for each changed line, with the old and new file in turn. This took 36 s.
  it 'finds the scope of each of 20,000 changed lines in a short time' do
    methods = Array.new(10_000) { "  def m#{it} = 1\n" }
    statements = Array.new(10_000) { "x#{it} = 1\n" }
    old_lines = ["class A\n", *methods, "end\n", *statements]
    new_lines = old_lines.map { it.sub('1', '2') }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    (2..old_lines.size).each { |line| [old_lines, new_lines].each { finder.call(it, line) } }

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
  end
end
