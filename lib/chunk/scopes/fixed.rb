# frozen_string_literal: true

module Chunk
  module Scopes
    # Finder: a fixed number of lines on each side of the changed line.
    class Fixed
      # @param radius [Integer] lines to keep on each side
      def initialize(radius)
        @radius = radius
      end

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range] 1-based line numbers
      def call(lines, line_number)
        [line_number - @radius, 1].max..[line_number + @radius, lines.size].min
      end
    end
  end
end
