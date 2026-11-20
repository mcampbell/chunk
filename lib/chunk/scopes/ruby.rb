# frozen_string_literal: true

require 'prism'

module Chunk
  module Scopes
    # Finder: the innermost method, else the innermost class or module, that holds the line.
    class Ruby
      include Cached

      CONTAINERS = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze
      # For each line number: the innermost method range, and the innermost class or module range.
      Analysis = Data.define(:defs, :containers)

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, nil when no method or class holds the line
      # @raise [Unreadable] when the file has a syntax error
      def call(lines, line_number)
        data = cached(lines) { analyze(lines) }
        data.defs[line_number] || data.containers[line_number]
      end

      private

      def analyze(lines)
        result = Prism.parse(lines.join)
        raise Unreadable, result.errors.first.message if result.errors.any?

        defs, containers = ranges(result.value)
        Analysis.new(by_line(defs, lines.size), by_line(containers, lines.size))
      end

      # One walk of the tree, with a stack in place of recursion, so a deep tree cannot overflow.
      def ranges(root)
        defs = []
        containers = []
        stack = [root]
        while (node = stack.pop)
          range = node.location.start_line..node.location.end_line
          defs << range if node.is_a?(Prism::DefNode)
          containers << range if CONTAINERS.any? { node.is_a?(it) }
          stack.concat(node.compact_child_nodes)
        end
        [defs, containers]
      end

      # Larger ranges first, so the innermost range is the last one written for each line.
      def by_line(ranges, size)
        ranges.sort_by { -it.size }.each_with_object(Array.new(size + 1)) do |range, result|
          range.each { result[it] = range }
        end
      end
    end
  end
end
