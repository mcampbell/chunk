# frozen_string_literal: true

module Chunk
  # Rebuilds the diff text of one file: one hunk for each merged scope of a change.
  class HunkBuilder
    MARKERS = { context: ' ', added: '+', deleted: '-' }.freeze
    # An added row has its scope in the new file, a deleted row in the old file.
    SIDES = { added: :new_no, deleted: :old_no }.freeze

    # @param finder [#call] (lines, line_number) -> Range, the scope of a change
    def initialize(finder)
      @finder = finder
    end

    # @param diff_file [Chunk::DiffFile]
    # @return [String] header text, then one hunk for each scope
    def build(diff_file)
      rows = diff_file.rows
      lines = { old_no: diff_file.old_lines, new_no: diff_file.new_lines }
      hunks = merge(spans(rows, lines)).map { |span| hunk(rows, span) }
      (diff_file.header + hunks).join
    end

    private

    # @return [Array<Range>] row-index span of the scope of each changed row
    def spans(rows, lines)
      positions = lines.keys.to_h { |field| [field, positions(rows, field)] }
      rows.each_index.filter_map do |idx|
        next unless (field = SIDES[rows[idx].kind])

        range = @finder.call(lines[field], rows[idx].public_send(field))
        span(rows, positions[field], field, range, idx)
      end
    end

    # Row indexes that have a line number on one side, in line number order, for a binary search.
    def positions(rows, field) = rows.each_index.select { rows[it].public_send(field) }

    # Rows between the range ends on one side. The span always holds the changed row, even when the finder misses it.
    def span(rows, positions, field, range, idx)
      first = positions.bsearch_index { rows[it].public_send(field) >= range.begin }
      after = positions.bsearch_index { rows[it].public_send(field) > range.end } || positions.size
      [first ? positions[first] : idx, idx].min..[after.positive? ? positions[after - 1] : idx, idx].max
    end

    def merge(spans)
      spans.sort_by(&:begin).each_with_object([]) do |span, merged|
        if merged.any? && span.begin <= merged.last.end + 1
          merged[-1] = merged.last.begin..[merged.last.end, span.end].max
        else
          merged << span
        end
      end
    end

    def hunk(rows, span)
      body = rows[span]
      old_start, old_count = side(rows, span, body, :old_no)
      new_start, new_count = side(rows, span, body, :new_no)
      "@@ -#{old_start},#{old_count} +#{new_start},#{new_count} @@\n#{body.map { |r| line(r) }.join}"
    end

    # @return [Array<Integer>] start and count of the span on one side
    def side(rows, span, body, field)
      numbers = body.filter_map(&field)
      start = numbers.first || rows[0...span.begin].filter_map(&field).last || 0
      [start, numbers.size]
    end

    def line(row)
      "#{MARKERS.fetch(row.kind)}#{row.text}#{"\n\\ No newline at end of file\n" if row.no_newline}"
    end
  end
end
