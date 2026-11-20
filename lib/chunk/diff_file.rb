# frozen_string_literal: true

module Chunk
  # One file of a diff made with all lines as context: its git header lines, and its rows.
  DiffFile = Data.define(:header, :rows)

  # Reads the full-file diff text, and rebuilds the old and new file from the rows.
  class DiffFile
    # One diff line. old_no or new_no is nil on the side where the line does not exist.
    # text has no leading marker, and ends with "\n" unless no_newline is true.
    Row = Data.define(:kind, :old_no, :new_no, :text, :no_newline)

    HUNK = /\A@@ -(\d+)(?:,\d+)? \+(\d+)/
    KINDS = { ' ' => :context, '+' => :added, '-' => :deleted }.freeze

    # @param text [String] output of Chunk::Git#full_diff
    # @return [Array<Chunk::DiffFile>] one for each file, in diff order
    def self.parse(text)
      text.split(/^(?=diff --git )/).map do |chunk|
        lines = chunk.lines
        header = lines.take_while { |line| !line.start_with?('@@') }
        new(header, build_rows(lines.drop(header.size)))
      end
    end

    def self.build_rows(lines)
      rows = []
      numbers = [0, 0]
      lines.each do |line|
        if (hunk = HUNK.match(line)) then numbers = [hunk[1].to_i, hunk[2].to_i]
        elsif line.start_with?('\\') then rows[-1] = rows.last.with(no_newline: true, text: rows.last.text.chomp)
        else rows << build_row(line, numbers)
        end
      end
      rows
    end

    # Reads one row, and moves the line numbers on by it.
    def self.build_row(line, numbers)
      kind = KINDS.fetch(line[0])
      old_no, new_no = numbers
      numbers[0] += 1 unless kind == :added
      numbers[1] += 1 unless kind == :deleted
      Row.new(kind, (old_no unless kind == :added), (new_no unless kind == :deleted), line[1..], false)
    end
    private_class_method :build_rows, :build_row

    # @return [String] the head path of the file, or the base path of a deleted file
    def path
      line = header.find { it.start_with?('+++ b/') } || header.find { it.start_with?('--- a/') }
      line ? line[6..].chomp : header.first[%r{ b/(.*)$}, 1]
    end

    # @return [Array<String>] the lines of the merge-base file
    def old_lines = rows.reject { |row| row.kind == :added }.map(&:text)

    # @return [Array<String>] the lines of the head file
    def new_lines = rows.reject { |row| row.kind == :deleted }.map(&:text)
  end
end
