---
type: Component
title: Hunk builder
description: DiffFile parses the full-file diff into rows, and HunkBuilder keeps only the rows in the scope of each change.
resource: lib/chunk/hunk_builder.rb
tags: [diff, hunks]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-20T19:38:33Z' }
sources:
  - id: lib-egm
    resource: /lib/chunk/EGM.md
    title: lib/chunk directory contract
---

# Overview

The [merge-base diff](/components/merge-base-diff.md) runs with `--unified=999999`, so each hunk holds the complete file. `Chunk::DiffFile.parse` turns each file into rows (`kind`, `old_no`, `new_no`, `text`, `no_newline`), and rebuilds the old and new file from them, so the tool needs no `git show`. `Chunk::HunkBuilder` asks a [scope finder](/components/scope-finders.md) for the range of each changed row, and writes new hunks.[^lib-egm]

# Rules

- An added row uses the new file. A deleted row uses the old file.
- A range becomes a row span: from the first row at or after the range start, to the last row at or before the range end, on that side. The span always holds the changed row.
- Spans that overlap or touch merge into one hunk.
- A hunk side with no lines starts at the line before it, or 0.
- A binary, rename-only, or mode-only file has no rows. Its header passes through unchanged.
- The specs apply each rebuilt diff with `git apply --check` at the merge base.

[^lib-egm]: lib/chunk directory contract
