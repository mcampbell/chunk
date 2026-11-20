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
        elsif line.start_with?('\\') then rows[-1] = without_newline(rows.last)
        else rows << build_row(line, numbers)
        end
      end
      rows
    end

    # Only the newline goes: a Windows line keeps its carriage return.
    def self.without_newline(row) = row.with(no_newline: true, text: row.text.delete_suffix("\n"))

    # Reads one row, and moves the line numbers on by it.
    def self.build_row(line, numbers)
      kind = KINDS.fetch(line[0])
      old_no, new_no = numbers
      numbers[0] += 1 unless kind == :added
      numbers[1] += 1 unless kind == :deleted
      Row.new(kind, (old_no unless kind == :added), (new_no unless kind == :deleted), line[1..], false)
    end
    private_class_method :build_rows, :build_row, :without_newline

    # Git C-style escapes in a quoted name (core.quotePath).
    ESCAPES = { 'a' => "\a", 'b' => "\b", 't' => "\t", 'n' => "\n", 'v' => "\v", 'f' => "\f", 'r' => "\r" }.freeze

    # @return [String] the head path of the file, or the base path of a deleted file
    def path
      # The a/ and b/ prefixes come from Chunk::Git#diff_args. /dev/null has neither.
      line = header.find { it.match?(%r{\A\+\+\+ "?b/}) } || header.find { it.match?(%r{\A--- "?a/}) }
      # Git adds a tab after a name with a space.
      return unquote(line[4..].chomp.delete_suffix("\t")).sub(%r{\A[ab]/}, '') if line

      header_path
    end

    private

    # A mode change or a rename with no content change has no --- or +++ line. With no rename, both
    # names in "diff --git a/NAME b/NAME" match, so the second half of the line is the name.
    def header_path
      renamed = header.find { it.start_with?('rename to ') }
      return unquote(renamed.chomp.delete_prefix('rename to ')) if renamed

      names = header.first.chomp.delete_prefix('diff --git ')
      unquote(names[((names.size + 1) / 2)..]).sub(%r{\A[ab]/}, '')
    end

    # Bytes that are not UTF-8 become U+FFFD, so such a path only names the file; it does not open it.
    def unquote(name)
      return name unless name.start_with?('"')

      bytes = name[1..-2].b.gsub(/\\([0-7]{3}|.)/n) do
        code = Regexp.last_match(1)
        code.size == 3 ? code.to_i(8).chr : ESCAPES.fetch(code, code)
      end
      bytes.force_encoding(Encoding::UTF_8).scrub
    end

    public

    # @return [Array<String>] the lines of the merge-base file
    def old_lines = rows.reject { |row| row.kind == :added }.map(&:text)

    # @return [Array<String>] the lines of the head file
    def new_lines = rows.reject { |row| row.kind == :deleted }.map(&:text)
  end
end
