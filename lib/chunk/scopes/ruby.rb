# frozen_string_literal: true

require 'prism'

module Chunk
  module Scopes
    # Finder: the innermost method, else the innermost class or module, that holds the line.
    class Ruby
      include Cached

      DEFS = [Prism::DefNode].freeze
      CONTAINERS = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

      # @param lines [Array<String>] the file lines
      # @param line_number [Integer] 1-based changed line
      # @return [Range, nil] 1-based line numbers, nil when no method or class holds the line
      # @raise [Unreadable] when the file has a syntax error
      def call(lines, line_number)
        root = parse(lines)
        found = innermost(root, line_number, DEFS) || innermost(root, line_number, CONTAINERS)
        found && (found.location.start_line..found.location.end_line)
      end

      private

      def parse(lines)
        cached(lines) do
          result = Prism.parse(lines.join)
          raise Unreadable, result.errors.first.message if result.errors.any?

          result.value
        end
      end

      def innermost(node, line_number, types)
        node.compact_child_nodes.each do |child|
          next unless line_number.between?(child.location.start_line, child.location.end_line)

          return innermost(child, line_number, types) || (child if types.any? { |t| child.is_a?(t) })
        end
        nil
      end
    end
  end
end
