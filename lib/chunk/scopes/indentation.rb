# frozen_string_literal: true

module Chunk
  module Scopes
    # Finder: the block of the nearest less-indented line above the changed line.
    class Indentation
      CLOSERS = /\A(end\b|[}\])]|<\/)/

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, nil at indentation level 0 or with no header
      def call(lines, line_number)
        base = base_index(lines, line_number - 1)
        return unless base

        level = indent(lines[base])
        return if level.zero?

        header = base.downto(0).find { |i| !blank?(lines[i]) && indent(lines[i]) < level }
        return unless header

        (header + 1)..(block_end(lines, header) + 1)
      end

      private

      # A blank line uses the next non-blank line below, else the nearest above.
      def base_index(lines, index)
        return index unless blank?(lines[index])

        (index...lines.size).find { |i| !blank?(lines[i]) } || index.downto(0).find { |i| !blank?(lines[i]) }
      end

      def block_end(lines, header)
        stop = next_stop(lines, header)
        return stop if stop && lines[stop].strip.match?(CLOSERS)

        last = (stop || lines.size) - 1
        last -= 1 while blank?(lines[last]) # the header is non-blank, so this ends
        last
      end

      def next_stop(lines, header)
        level = indent(lines[header])
        ((header + 1)...lines.size).find { |i| !blank?(lines[i]) && indent(lines[i]) <= level }
      end

      def blank?(line)
        line.strip.empty?
      end

      def indent(line)
        line[/\A[ \t]*/].chars.sum { |c| c == "\t" ? 8 : 1 }
      end
    end
  end
end
