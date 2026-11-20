# frozen_string_literal: true

require 'open3'

module Chunk
  # Reads diffs from a local git repository. It never changes the working tree or the index.
  class Git
    # @param repo_path [String] path to a directory in the git repository
    def initialize(repo_path)
      @repo_path = repo_path
    end

    # Gives the diff from the merge base of base and head to head, as GitHub PR diffs do.
    #
    # @param base [String] base ref, for example a branch name or a SHA
    # @param head [String] head ref
    # @return [String] the unified diff text
    # @raise [Chunk::Error] when git fails, for example on an unknown ref
    def diff(base, head)
      run('diff', '--no-color', '--no-ext-diff', '--no-textconv', '--end-of-options', "#{base}...#{head}")
    end

    # @return [String] path of the top directory of the repository
    # @raise [Chunk::Error] when the path is not in a git repository
    def toplevel
      run('rev-parse', '--show-toplevel').strip
    end

    private

    def run(*)
      out, err, status = Open3.capture3('git', '-C', @repo_path, *)
      raise Error, err.strip unless status.success?

      out
    end
  end
end
