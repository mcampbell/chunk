# frozen_string_literal: true

# Diff viewer that shows each change with its complete scope.
module Chunk
  # Raised for a failure that the user must see, for example a git error.
  class Error < StandardError; end
end
