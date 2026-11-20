# chunk

## Overview

Command-line diff viewer for GitHub pull requests (PRs). It writes one HTML file that shows a diff the way GitHub does, but with more context: each change shows the complete function, class, indentation block, or paragraph that holds it. Ruby 3.4.

Status (2026-11-20): design only. The repository has no code yet. Each directory below is planned. Design docs are in `tmp/`, which git ignores.

## Subdirectories & Boundaries

- bin (planned) - `bin/chunk`, the command.
- lib/chunk (planned) - git access, hunk builder, scope finders, HTML page.
- script (planned) - Node script that finds function and class ranges in TypeScript and JavaScript.
- vendor/diff2html (planned) - diff2html CSS and JavaScript. Each HTML file holds a copy.
- spec (planned) - RSpec specs.

## Interface

- `bin/chunk [--repo PATH] BASE HEAD` (planned) - writes `~/tmp/chunk/<repo>-<base>-<head>.html`, prints the path, and opens the file with `open`.

## Invariants

- The diff goes from the merge base to the head (`git diff BASE...HEAD`), as GitHub PR diffs do.
- The tool never changes the working tree or the index. It only reads git objects.
- Context for each changed line:
  - Ruby: the innermost method. If none, the innermost class or module. If none, 10 lines.
  - TypeScript and JavaScript: the innermost function. If none, the innermost class. If none, 10 lines.
  - Other files, and files the parser cannot read: the indentation block. If none, or at indentation level 0, the paragraph between blank lines.
- The HTML file works offline. All CSS and JavaScript are inside it.
- The tool keeps no credentials. It uses the auth of `git` and `gh`.

## Side Effects

- Writes one HTML file under `~/tmp/chunk/`.
- Starts `git`, `node`, and `open`.

## Verification

- Run all specs (planned): `bundle exec rspec`
