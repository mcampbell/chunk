---
type: Component
title: Merge-base diff
description: Chunk::Git gives the diff from the merge base of two refs to the head, as GitHub pull request diffs do.
resource: lib/chunk/git.rb
tags: [git, diff]
status: stable
generated: { by: claude-code/claude-opus-5-5, at: '2026-11-20T18:19:50Z' }
sources:
  - id: lib-egm
    resource: /lib/chunk/EGM.md
    title: lib/chunk directory contract
  - id: github-compare
    resource: https://docs.github.com/en/pull-requests/reference/branches#three-dot-and-two-dot-git-diff-comparisons
    title: GitHub three-dot and two-dot comparisons
---

# Overview

`Chunk::Git.new(repo_path).diff(base, head)` runs `git diff BASE...HEAD`. A pull request diff on GitHub also starts at the merge base, so changes made only on the base branch after the fork do not show.[^github-compare] `full_diff(base, head)` gives the same diff with each line of each changed file as context, for the [hunk builder](/components/hunk-builder.md). The [chunk command](/components/chunk-command.md) uses it.

# Rules

- Read-only: the command never changes the working tree or the index.[^lib-egm]
- `--end-of-options` comes before the refs, so a ref is never read as a git option.
- An empty or blank ref raises `Chunk::Error`. Git reads `...HEAD` as `HEAD...HEAD`, which gives a wrong diff with no error.
- Pinned flags: `--no-color`, `--no-ext-diff`, `--no-textconv`, `--src-prefix=a/`, `--dst-prefix=b/`. User git config cannot change the diff text.
- The output is valid UTF-8. Each byte that is not UTF-8 becomes U+FFFD.

[^lib-egm]: lib/chunk directory contract
[^github-compare]: GitHub three-dot and two-dot comparisons
