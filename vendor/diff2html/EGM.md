# vendor/diff2html

## Overview

diff2html 3.4.56 from npm (MIT). `Chunk::Page` puts both files inline in each HTML page. See `README.md` for the version and the source.

## Interface

- `diff2html-ui-slim.min.js` - sets the global `Diff2HtmlUI`.
- `diff2html.min.css` - styles for the diff tables.

## Invariants

- Do not edit the files by hand. To upgrade, copy the same files from a new npm package and update `README.md`.
- The script must not hold `</script` or `<script` followed by whitespace, `/`, or `>`. Either one breaks the inline script element. `spec/chunk/page_spec.rb` checks this.

## Side Effects

- None.
