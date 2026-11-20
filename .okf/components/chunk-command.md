---
type: Command
title: chunk command
description: The bin/chunk command that writes and opens the diff page for two git refs.
resource: bin/chunk
tags: [cli, entry-point]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-20T18:19:50Z' }
sources:
  - id: readme
    resource: /README.md
    title: chunk README
  - id: lib-egm
    resource: /lib/chunk/EGM.md
    title: lib/chunk directory contract
---

# Overview

`bin/chunk [--repo PATH] BASE HEAD` calls `Chunk::Cli`. It gets the [merge-base diff](/components/merge-base-diff.md), builds the [offline diff page](/components/offline-diff-page.md), writes it to `~/tmp/chunk/<repo>-<base>-<head>.html`, prints the path, and opens it with `open`.[^readme]

# Interface

| Input | Meaning |
|---|---|
| `BASE`, `HEAD` | Branch names, tags, or SHAs. |
| `--repo PATH` | The repository. Default: the current directory. |
| `CHUNK_OUTPUT_DIR` | The page directory. Default: `~/tmp/chunk`. |

| Exit status | Meaning |
|---|---|
| 0 | Page written. Also when `open` fails (a warning is printed). |
| 1 | `Chunk::Error` or `SystemCallError`: prints `chunk: <message>`. |
| 2 | Wrong usage: prints the OptionParser message and the usage line. |

# Rules

- Each character outside `[A-Za-z0-9._-]` in the repository name and the refs becomes `-` in the file name. Git refuses `..` in ref names, so a ref cannot move the page out of the output directory.[^lib-egm]
- The specs inject the open step (`opener:`), so a test never starts a browser.

[^readme]: chunk README
[^lib-egm]: lib/chunk directory contract
