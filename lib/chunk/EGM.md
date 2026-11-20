# lib/chunk

## Overview

The code of the `chunk` command. `Cli` reads the arguments, `Git` gets the diff, and `Page` writes the HTML.

## Interface

- `Chunk::Cli.new(argv, env: ENV, out: $stdout, err: $stderr, opener: ...).run` - gives the exit status (0, 1, or 2). `opener` gets the page path. A falsy result prints "could not open" and still gives 0.
- `Chunk::Git.new(repo_path).diff(base, head)` - the diff text of `git diff BASE...HEAD`. Raises `Chunk::Error` with the git stderr text.
- `Chunk::Git.new(repo_path).toplevel` - the top directory of the repository.
- `Chunk::Page.new(diff_text, title:, warnings: []).to_html` - one HTML document. An empty diff shows "No changes".
- `Chunk::Error` - a failure the user must see. `Cli` prints it and gives 1.

## Invariants

- `Git` passes `--end-of-options` before the refs, so a ref can never be read as a git option.
- `Git` runs only read commands (`diff`, `rev-parse`). It starts `git` with an argument array, never through a shell.
- `Git` turns off color, external diff tools, and textconv, so the diff matches GitHub.
- `Page` escapes each `<` in the embedded diff data as `<`, so no diff text can end the script element.
- `Page` replaces bytes that are not UTF-8 with U+FFFD, so a Latin-1 file does not stop the page.
- `Page` holds all CSS and JavaScript inline: `vendor/diff2html`, `page.css`, and `page.js`.
- The page starts in the side-by-side view. The button switches to the inline view and back.
- Page file name: each character outside `[A-Za-z0-9._-]` in the repository name and the refs becomes `-`.

## Side Effects

- `Cli` makes the output directory and writes one HTML file. It starts `open` through the default `opener`.
- `Git` starts `git`.

## Verification

- `bundle exec rspec spec/chunk`
