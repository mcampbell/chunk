# frozen_string_literal: true

require 'json'

RSpec.describe Chunk::Page do
  let(:diff_text) do
    <<~DIFF
      diff --git a/a.rb b/a.rb
      --- a/a.rb
      +++ b/a.rb
      @@ -1 +1 @@
      -old
      +new
    DIFF
  end

  def page(diff = diff_text, **)
    described_class.new(diff, title: 'chunk main...feature', **).to_html
  end

  # The browser ends a script element at the first "</script", so read the data the same way.
  def embedded_diff(html)
    content = html[%r{<script type="application/json" id="chunk-diff">(.*?)</script}m, 1]
    JSON.parse(content)
  end

  it 'works offline, with no external script or stylesheet' do
    html = page

    expect(html).not_to match(/<script[^>]*\ssrc=/i)
    expect(html).not_to match(/<link[^>]*\shref=/i)
    expect(html).to include('Diff2HtmlUI')
  end

  it 'gives the browser the diff text unchanged' do
    expect(embedded_diff(page)).to eq(diff_text)
  end

  it 'keeps a diff that holds HTML markup inside its data block' do
    hostile = "#{diff_text}+</script><!--<script>alert(1)</script>\n"

    html = page(hostile)

    expect(embedded_diff(html)).to eq(hostile)
    expect(html).not_to include('<script>alert(1)')
  end

  it 'shows a diff with bytes that are not UTF-8 in place of failing' do
    latin1 = "#{diff_text}+caf\xE9\n".b

    expect(embedded_diff(page(latin1))).to include('caf�')
  end

  it 'starts in the side-by-side view, with a switch to the inline view' do
    html = page

    expect(html).to include('data-format="side-by-side"')
    expect(html).to include('id="chunk-view-switch"')
  end

  it 'shows each warning above the diff, as text' do
    html = page(warnings: ['a.ts: <node> not found'])

    expect(html).to include('a.ts: &lt;node&gt; not found')
    expect(html.index('a.ts: &lt;node&gt;')).to be < html.index('chunk-diff-view')
  end

  it 'shows the title as text' do
    html = described_class.new(diff_text, title: '<b>main</b>').to_html

    expect(html).to include('<title>&lt;b&gt;main&lt;/b&gt;</title>')
  end

  it 'says so when the refs have no changes' do
    html = page('')

    expect(html).to include('No changes')
    expect(html).not_to include('chunk-view-switch')
  end

  it 'uses a diff2html bundle that can sit inside an inline script element' do
    script = File.read(described_class::VENDOR_SCRIPT)

    expect(script).not_to match(%r{</script}i)
    expect(script).not_to match(%r{<script[\s/>]}i)
  end
end
