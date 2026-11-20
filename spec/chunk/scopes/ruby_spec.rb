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
end
