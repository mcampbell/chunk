---
type: Component
title: Scope finders
description: Chunk::Scopes picks the line range that each change shows, with a chain of finders for each file type.
resource: lib/chunk/scopes.rb
tags: [scopes, context]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-20T19:38:33Z' }
sources:
  - id: lib-egm
    resource: /lib/chunk/EGM.md
    title: lib/chunk directory contract
  - id: root-egm
    resource: /EGM.md
    title: Root directory contract
---

# Overview

A finder has one method, `call(lines, line_number)`, which gives a `Range` of 1-based lines or `nil`. `Chunk::Scopes.finder_for(path, warnings)` picks the chain for the file name. The first non-nil range wins. If each finder gives `nil`, the scope is the changed line only. The [hunk builder](/components/hunk-builder.md) uses it.[^lib-egm]

# Chains

| File type | Chain | Status |
|---|---|---|
| All files (default) | Indentation block, then paragraph | PR 3 |
| Ruby | Prism (method, then class), then 10 lines | PR 4 |
| TypeScript and JavaScript | Node `typescript` script (function, then class), then 10 lines | PR 5 |

A finder that cannot read the file raises `Chunk::Scopes::Unreadable`. The file then uses the default chain, and the page shows one warning for it.[^root-egm]

[^lib-egm]: lib/chunk directory contract
[^root-egm]: Root directory contract
