# frozen_string_literal: true

module Chunk
  # Rebuilds the diff text of one file: one hunk for each merged scope of a change.
  class HunkBuilder
    MARKERS = { context: ' ', added: '+', deleted: '-' }.freeze

    # @param finder [#call] (lines, line_number) -> Range, the scope of a change
    def initialize(finder)
      @finder = finder
    end

    # @param diff_file [Chunk::DiffFile]
    # @return [String] header text, then one hunk for each scope
    def build(diff_file)
      rows = diff_file.rows
      hunks = merge(spans(diff_file)).map { |span| hunk(rows, span) }
      (diff_file.header + hunks).join
    end

    private

    # @return [Array<Range>] row-index span of the scope of each changed row
    def spans(diff_file)
      rows = diff_file.rows
      rows.each_index.filter_map do |idx|
        kind = rows[idx].kind
        next if kind == :context

        added = kind == :added
        field = added ? :new_no : :old_no
        range = @finder.call(added ? diff_file.new_lines : diff_file.old_lines, rows[idx].public_send(field))
        span(rows, field, range, idx)
      end
    end

    # Rows between the range ends on one side, widened to hold the changed row.
    def span(rows, field, range, idx)
      first = rows.index { |row| row.public_send(field)&.>=(range.begin) }
      last = rows.rindex { |row| row.public_send(field)&.<=(range.end) }
      [first || idx, idx].min..[last || idx, idx].max
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
