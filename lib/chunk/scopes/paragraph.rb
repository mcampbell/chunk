# frozen_string_literal: true

module Chunk
  module Scopes
    # Finder: the lines between the nearest blank lines around the changed line.
    class Paragraph
      include Cached

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, or nil when the file has no text
      def call(lines, line_number)
        paragraphs = cached(lines) { paragraphs(lines) }
        index = line_number - 1
        # A blank line uses the nearest text line below, else above.
        found = index.upto(lines.size - 1).find { paragraphs[it] } || index.downto(0).find { paragraphs[it] }
        found && paragraphs[found]
      end

      private

      # @return [Array<Range, nil>] the paragraph of each text line, nil for a blank line
      def paragraphs(lines)
        runs = lines.each_index.slice_when { |a, b| blank?(lines[a]) != blank?(lines[b]) }
        runs.flat_map { |run| [((run.first + 1)..(run.last + 1) unless blank?(lines[run.first]))] * run.size }
      end

      def blank?(line) = line.strip.empty?
    end
  end
end
