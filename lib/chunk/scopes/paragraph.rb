# frozen_string_literal: true

module Chunk
  module Scopes
    # Finder: the lines between the nearest blank lines around the changed line.
    class Paragraph
      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, or nil when the file has no text
      def call(lines, line_number)
        index = text_index(lines, line_number - 1)
        return nil unless index

        first = last = index
        first -= 1 while first.positive? && !blank?(lines[first - 1])
        last += 1 while last < lines.size - 1 && !blank?(lines[last + 1])
        (first + 1)..(last + 1)
      end

      private

      # Nearest non-blank index at or below the start, else above it.
      def text_index(lines, start)
        start.upto(lines.size - 1).find { |i| !blank?(lines[i]) } ||
          start.downto(0).find { |i| !blank?(lines[i]) }
      end

      def blank?(line)
        line.strip.empty?
      end
    end
  end
end
