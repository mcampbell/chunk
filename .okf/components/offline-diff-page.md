---
type: Component
title: Offline diff page
description: Chunk::Page builds one HTML file that shows a diff with diff2html, with no network access.
resource: lib/chunk/page.rb
tags: [html, diff2html]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-20T18:19:50Z' }
sources:
  - id: lib-egm
    resource: /lib/chunk/EGM.md
    title: lib/chunk directory contract
  - id: vendor-egm
    resource: /vendor/diff2html/EGM.md
    title: vendor/diff2html directory contract
---

# Overview

`Chunk::Page.new(diff_text, title:, warnings: []).to_html` gives one HTML document. It holds the diff2html 3.4.56 slim UI bundle and CSS, `page.css`, and `page.js` inline, so it works offline.[^vendor-egm] The page starts in the side-by-side view, and a button switches to the inline view. The [chunk command](/components/chunk-command.md) writes it.

# Rules

- The diff is JSON in `<script type="application/json" id="chunk-diff">`. Each `<` is escaped as `\u003c`, so no diff text can end the script element.[^lib-egm]
- Files are read as UTF-8, so a shell with `LANG=C` still gives a page.
- The vendor script must not hold `</script`, or `<script` followed by whitespace, `/`, or `>`. A spec checks this after each upgrade.
- An empty diff shows "No changes". Each warning shows as one line above the diff.

[^lib-egm]: lib/chunk directory contract
[^vendor-egm]: vendor/diff2html directory contract
