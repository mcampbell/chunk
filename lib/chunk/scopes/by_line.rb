# frozen_string_literal: true

module Chunk
  module Scopes
    # Turns nested line ranges into a lookup by line number, so each call is one array read.
    module ByLine
      private

      # @param ranges [Array<Range>] nested or separate 1-based line ranges
      # @param size [Integer] the number of lines in the file
      # @return [Array<Range, nil>] for each line number, the innermost range that holds it
      def by_line(ranges, size)
        # Larger ranges first, so the innermost range is the last one written for each line.
        ranges.sort_by { -it.size }.each_with_object(Array.new(size + 1)) do |range, result|
          range.each { result[it] = range }
        end
      end
    end
  end
end
