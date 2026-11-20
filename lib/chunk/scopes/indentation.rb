# frozen_string_literal: true

module Chunk
  module Scopes
    # Finder: the block of the nearest less-indented line above the changed line.
    class Indentation
      include Cached

      # A YAML key such as end: or endpoint: is not a closer.
      CLOSERS = /\A(end(?![\w:])|[}\])]|<\/)/
      # levels: indentation of each line, nil for a blank line. parents: index of the header of each
      # line. ends: index of the last line of each block, filled when first asked.
      Analysis = Data.define(:levels, :parents, :ends)

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, nil for a line with no header (a level-0 line that is not a closing line)
      def call(lines, line_number)
        data = cached(lines) { analyze(lines) }
        base = base_index(data.levels, line_number - 1)
        header = base && header_index(lines, data, base)
        block(lines, data, header) if header
      end

      private

      # A closing line belongs to the block it closes: its header is the nearest line above at its level.
      def header_index(lines, data, base)
        return data.parents[base] unless lines[base].strip.match?(CLOSERS)

        (base - 1).downto(0).find { data.levels[it] && data.levels[it] <= data.levels[base] } || data.parents[base]
      end

      def block(lines, data, header)
        (header + 1)..((data.ends[header] ||= block_end(lines, data.levels, header)) + 1)
      end

      def analyze(lines)
        levels = lines.map { |line| line.strip.empty? ? nil : indent(line) }
        Analysis.new(levels, parents(levels), {})
      end

      # The nearest line above with less indentation, for each line, in one pass with a stack.
      def parents(levels)
        stack = []
        levels.each_with_index.map do |level, index|
          next unless level

          stack.pop while stack.any? && levels[stack.last] >= level
          stack.last.tap { stack << index }
        end
      end

      # A blank line uses the next non-blank line below, else the nearest above.
      def base_index(levels, index)
        return index if levels[index]

        (index...levels.size).find { levels[it] } || index.downto(0).find { levels[it] }
      end

      def block_end(lines, levels, header)
        stop = ((header + 1)...levels.size).find { levels[it] && levels[it] <= levels[header] }
        return stop if stop && lines[stop].strip.match?(CLOSERS)

        (header...(stop || levels.size)).reverse_each.find { levels[it] }
      end

      # A tab moves to the next multiple of 8 columns.
      def indent(line)
        line[/\A[ \t]*/].each_char.reduce(0) { |column, char| char == "\t" ? ((column / 8) + 1) * 8 : column + 1 }
      end
    end
  end
end
