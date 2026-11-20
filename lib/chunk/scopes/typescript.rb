# frozen_string_literal: true

require 'json'
require 'open3'

module Chunk
  module Scopes
    # Finder: the innermost function, else the innermost class, that holds the line, from the
    # TypeScript compiler in script/ts_scopes.mjs (needs `node` and `npm ci`).
    class Typescript
      include Cached
      include ByLine

      SCRIPT = File.expand_path('../../../script/ts_scopes.mjs', __dir__)
      # For each line number: the innermost function range, and the innermost class range.
      Analysis = Data.define(:functions, :classes)

      # @param extension [String] for example '.ts' or '.jsx'; it picks the TypeScript or JSX syntax
      def initialize(extension)
        @extension = extension
      end

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, nil when no function or class holds the line
      # @raise [Unreadable] when node or the typescript package is missing, or the file has a syntax error
      def call(lines, line_number)
        data = cached(lines) { analyze(lines) }
        data.functions[line_number] || data.classes[line_number]
      end

      private

      def analyze(lines)
        ranges = scopes(lines).group_by { it['kind'] }.transform_values { |list| list.map { it['start']..it['end'] } }
        Analysis.new(by_line(ranges.fetch('function', []), lines.size), by_line(ranges.fetch('class', []), lines.size))
      end

      def scopes(lines)
        # shortcut: no timeout, so a hung node stops chunk; add one if that happens.
        out, err, status = Open3.capture3('node', SCRIPT, "file#{@extension}", stdin_data: lines.join)
        raise Unreadable, message(utf8(err)) unless status.success?

        JSON.parse(utf8(out))
      rescue SystemCallError => e
        raise Unreadable, "node: #{e.message}"
      rescue JSON::ParserError => e
        raise Unreadable, "#{SCRIPT}: #{e.message}"
      end

      # A Node error has a source location first, then the "Error ..." line.
      def message(err) = (err.lines.find { it.start_with?('Error') } || err.lines.first).to_s.strip

      # Process output has no encoding tag, and Ruby uses the shell locale.
      def utf8(text) = text.force_encoding(Encoding::UTF_8).scrub
    end
  end
end
