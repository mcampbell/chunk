# frozen_string_literal: true

require 'erb'
require 'json'

module Chunk
  # Builds one HTML page that shows a diff with diff2html. The page holds all its CSS and
  # JavaScript, so it works offline.
  class Page
    VENDOR_DIR = File.expand_path('../../vendor/diff2html', __dir__)
    VENDOR_SCRIPT = File.join(VENDOR_DIR, 'diff2html-ui-slim.min.js')
    VENDOR_STYLE = File.join(VENDOR_DIR, 'diff2html.min.css')
    PAGE_STYLE = File.join(__dir__, 'page.css')
    PAGE_SCRIPT = File.join(__dir__, 'page.js')
    TEMPLATE = ERB.new(File.read(File.join(__dir__, 'page.html.erb'), encoding: Encoding::UTF_8), trim_mode: '-')

    # @param diff_text [String] unified diff text, as valid UTF-8
    # @param title [String] page title
    # @param warnings [Array<String>] lines to show above the diff
    def initialize(diff_text, title:, warnings: [])
      @diff_text = diff_text
      @title = title
      @warnings = warnings
    end

    # @return [String] the complete HTML document
    def to_html
      TEMPLATE.result(binding)
    end

    private

    def empty? = @diff_text.strip.empty?

    def h(text) = ERB::Util.html_escape(text)

    # Escape each "<" so that no text in the diff can end the script element.
    def diff_json = JSON.generate(@diff_text).gsub('<') { '\u003c' }

    def read(path) = File.read(path, encoding: Encoding::UTF_8)
  end
end
