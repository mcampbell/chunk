# frozen_string_literal: true

require_relative 'scopes/cached'
require_relative 'scopes/by_line'
require_relative 'scopes/fixed'
require_relative 'scopes/paragraph'
require_relative 'scopes/indentation'
require_relative 'scopes/ruby'
require_relative 'scopes/typescript'

module Chunk
  # Picks the scope (line range) of a change for each file type.
  module Scopes
    # Raised by a finder that cannot read the file.
    class Unreadable < StandardError; end

    DEFAULT_CHAIN = [Indentation.new, Paragraph.new].freeze

    # Basename pattern => finders, one entry for each file type. The first pattern that matches wins.
    CHAINS = {
      '{*.rb,*.rake,*.gemspec,*.ru,Gemfile,Rakefile}' => [Ruby.new, Fixed.new(10)],
      # One finder for each extension: the script picks the TypeScript or JSX syntax from it.
      **%w[.ts .tsx .js .jsx .mjs .cjs].to_h { ["*#{it}", [Typescript.new(it), Fixed.new(10)]] }
    }.freeze

    # @param path [String] file path
    # @param warnings [Array<String>] receives one message on the first Unreadable
    # @param chains [Hash] basename pattern => finders
    # @return [#call] (lines, line_number) -> Range
    def self.finder_for(path, warnings, chains: CHAINS)
      name = File.basename(path)
      chain = chains.find { |pattern, _| File.fnmatch?(pattern, name, File::FNM_EXTGLOB) }&.last || DEFAULT_CHAIN
      lambda do |lines, line_number|
        run(chain, lines, line_number)
      rescue Unreadable => e
        warnings << "#{path}: #{e.message}"
        chain = DEFAULT_CHAIN
        run(chain, lines, line_number)
      end
    end

    # @return [Range] the first non-nil range of the chain, or n..n
    def self.run(chain, lines, line_number)
      chain.each do |finder|
        range = finder.call(lines, line_number)
        return range if range
      end
      line_number..line_number
    end
    private_class_method :run
  end
end
