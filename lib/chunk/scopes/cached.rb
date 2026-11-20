# frozen_string_literal: true

module Chunk
  module Scopes
    # Keeps the analysis of a file for the next calls. The hunk builder calls a finder once for each
    # changed line, with the old file and the new file in turn, so the cache keeps two files.
    module Cached
      private

      # @param lines [Array<String>] the file lines; the same array object gives the cached result, so a
      #   caller must not change the array after the first call (Chunk::HunkBuilder builds each array once)
      # @return [Object] the result of the block for these lines
      def cached(lines)
        @cache ||= {}.compare_by_identity
        @cache.clear if @cache.size >= 2 && !@cache.key?(lines)
        @cache[lines] ||= yield
      end
    end
  end
end
