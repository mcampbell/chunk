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
    # @return [String] the unified diff text, as valid UTF-8 (other bytes become U+FFFD)
    # @raise [Chunk::Error] when a ref is empty, or when git fails, for example on an unknown ref
    def diff(base, head) = run(*diff_args(base, head))

    # Gives the same diff as {#diff}, with every line of each changed file as context.
    # shortcut: a file longer than 999999 lines gets a cut hunk, raise the number when that happens.
    #
    # @param base [String] base ref
    # @param head [String] head ref
    # @return [String] the unified diff text, as valid UTF-8
    # @raise [Chunk::Error] as {#diff}
    def full_diff(base, head) = run(*diff_args(base, head, '--unified=999999'))

    # @return [String] path of the top directory of the repository
    # @raise [Chunk::Error] when the path is not in a git repository
    def toplevel
      run('rev-parse', '--show-toplevel').strip
    end

    private

    def diff_args(base, head, *extra)
      raise Error, 'a ref is empty' if [base, head].any? { |ref| ref.strip.empty? }

      ['diff', '--no-color', '--no-ext-diff', '--no-textconv', '--src-prefix=a/', '--dst-prefix=b/', *extra,
       '--end-of-options', "#{base}...#{head}"]
    end

    def run(*)
      out, err, status = Open3.capture3('git', '-C', @repo_path, *)
      raise Error, utf8(err).strip unless status.success?

      utf8(out)
    end

    # Git output has no encoding tag, and Ruby uses the shell locale. Each byte that is not UTF-8 becomes U+FFFD.
    def utf8(text) = text.force_encoding(Encoding::UTF_8).scrub
  end
end
