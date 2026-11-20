# frozen_string_literal: true

# Diff viewer that shows each change with its complete scope.
module Chunk
  # Raised for a failure that the user must see, for example a git error.
  class Error < StandardError; end
end

require_relative 'chunk/git'
require_relative 'chunk/page'
require_relative 'chunk/scopes'
require_relative 'chunk/cli'
