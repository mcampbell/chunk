# chunk

## Overview

Command-line diff viewer for GitHub pull requests (PRs). It writes one HTML file that shows a diff the way GitHub does, but with more context: each change shows the complete function, class, indentation block, or paragraph that holds it. Ruby 3.4.

Status (2026-11-20): PR 3 of 5. Each change shows its indentation block, else its paragraph. The Ruby and TypeScript rules under Invariants are planned for PRs 4 and 5. Design docs are in `tmp/`, which git ignores.

## Subdirectories & Boundaries

- bin (no EGM.md) - `bin/chunk`, the command. It only calls `Chunk::Cli`.
- lib/chunk: [./lib/chunk/EGM.md](./lib/chunk/EGM.md) - git access, diff parser, scope finders, hunk builder, HTML page, command.
- script (planned) - Node script that finds function and class ranges in TypeScript and JavaScript.
- vendor/diff2html: [./vendor/diff2html/EGM.md](./vendor/diff2html/EGM.md) - diff2html CSS and JavaScript. Each HTML file holds a copy.
- spec (no EGM.md) - RSpec specs. `spec/support/git_repo_helper.rb` makes throw-away git repositories.

## Interface

- `bin/chunk [--repo PATH] BASE HEAD` - writes `~/tmp/chunk/<repo>-<base>-<head>.html`, prints the path, and opens the file with `open`. `--repo` defaults to the current directory. Exit status: 0 success (also when `open` fails), 1 error (git, or the file system), 2 wrong usage. See `README.md`.
- `CHUNK_OUTPUT_DIR` - the directory for the page, in place of `~/tmp/chunk`.

## Invariants

- The diff goes from the merge base to the head (`git diff BASE...HEAD`), as GitHub PR diffs do.
- The tool never changes the working tree or the index. It only reads git objects.
- Context for each changed line:
  - Ruby (planned, PR 4): the innermost method. If none, the innermost class or module. If none, 10 lines.
  - TypeScript and JavaScript (planned, PR 5): the innermost function. If none, the innermost class. If none, 10 lines.
  - Other files, and files the parser cannot read: the indentation block. If none, or at indentation level 0, the paragraph between blank lines.
- The HTML file works offline. All CSS and JavaScript are inside it.
- The tool keeps no credentials. It uses the auth of `git` and `gh`.

## Side Effects

- Writes one HTML file under `~/tmp/chunk/`.
- Starts `git` and `open`. Planned: `node` (PR 5).

## Verification

- Run all specs: `bundle exec rspec`
- Lint: `bundle exec rubocop`
