# frozen_string_literal: true

RSpec.describe Chunk::Scopes::Cached do
  subject(:finder) do
    Class.new do
      include Chunk::Scopes::Cached

      attr_reader :analyses

      def call(lines) = cached(lines) { (@analyses = (@analyses || 0) + 1) && lines.size }
    end.new
  end

  # The hunk builder calls with the old file and the new file in turn, one call for each changed line.
  it 'analyzes the old file and the new file once each, when calls take turns' do
    old_lines = ["a\n"]
    new_lines = ["a\n"]

    3.times { [old_lines, new_lines].each { finder.call(it) } }

    expect(finder.analyses).to eq(2)
  end

  it 'analyzes a third file again, in place of keeping it with the first two' do
    files = Array.new(3) { ["a\n"] }

    files.each { finder.call(it) }
    finder.call(files.first)

    expect(finder.analyses).to eq(4)
  end
end
