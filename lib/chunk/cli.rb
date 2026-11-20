# frozen_string_literal: true

require 'fileutils'
require 'optparse'

module Chunk
  # The `chunk` command: writes the diff page for two refs and opens it.
  class Cli
    USAGE = 'Usage: chunk [--repo PATH] BASE HEAD'

    # @param argv [Array<String>] command-line arguments
    # @param env [Hash{String => String}] reads `CHUNK_OUTPUT_DIR`
    # @param out [IO] gets the page path
    # @param err [IO] gets errors and warnings
    # @param opener [#call] opens the page path; a falsy result means it failed
    def initialize(argv, env: ENV, out: $stdout, err: $stderr, opener: ->(path) { system('open', path) })
      @argv = argv
      @env = env
      @out = out
      @err = err
      @opener = opener
    end

    # @return [Integer] exit status: 0 success, 1 failure, 2 wrong usage
    def run
      repo, base, head = parse
      return usage unless head

      show(write_page(Git.new(repo), base, head))
    rescue OptionParser::ParseError => e
      @err.puts "chunk: #{e.message}"
      usage
    rescue Error, SystemCallError => e
      @err.puts "chunk: #{e.message}"
      1
    end

    private

    def parse
      repo = Dir.pwd
      refs = OptionParser.new { |opts| opts.on('--repo PATH') { |path| repo = path } }.parse(@argv)
      [repo, *refs] if refs.size == 2
    end

    def show(path)
      @out.puts path
      @err.puts "chunk: could not open #{path}" unless @opener.call(path)
      0
    end

    def usage
      @err.puts USAGE
      2
    end

    def write_page(git, base, head)
      name = File.basename(git.toplevel)
      dir = @env.fetch('CHUNK_OUTPUT_DIR', File.join(Dir.home, 'tmp', 'chunk'))
      path = File.join(dir, "#{[name, base, head].map { |part| part.gsub(/[^A-Za-z0-9._-]/, '-') }.join('-')}.html")
      FileUtils.mkdir_p(dir)
      File.write(path, Page.new(git.diff(base, head), title: "#{name} #{base}...#{head}").to_html)
      path
    end
  end
end
