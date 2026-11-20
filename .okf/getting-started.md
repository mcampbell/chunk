---
type: Reference
title: Getting started — chunk diff viewer
description: What chunk is, and where each part of it is described.
tags:
- getting-started
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: '2026-11-20T18:19:58Z'
sources:
  - id: readme
    resource: /README.md
    title: chunk README
  - id: root-egm
    resource: /EGM.md
    title: Root directory contract
---

# Overview

chunk is a command-line diff viewer for GitHub pull requests. It writes one offline HTML page that shows a diff in the GitHub style.[^readme] The plan is that each change shows its complete function, class, or block. Status: PR 3 of 5 shows the indentation block, else the paragraph, of each change.[^root-egm]

# Parts

- [chunk command](/components/chunk-command.md) - `bin/chunk`, arguments, exit status, output file.
- [Merge-base diff](/components/merge-base-diff.md) - `Chunk::Git`, the diff from the merge base.
- [Hunk builder](/components/hunk-builder.md) - `Chunk::DiffFile` and `Chunk::HunkBuilder`, the rows and the new hunks.
- [Scope finders](/components/scope-finders.md) - `Chunk::Scopes`, the line range of each change.
- [Offline diff page](/components/offline-diff-page.md) - `Chunk::Page`, the HTML with inline diff2html.

[^readme]: chunk README
[^root-egm]: Root directory contract
