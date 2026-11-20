# lib/chunk

## Overview

The code of the `chunk` command. `Cli` reads the arguments. `Git` gets the full-file diff. `DiffFile` parses it into rows. For each changed row, `Scopes` picks a line range, and `HunkBuilder` keeps only those rows. `Page` writes the HTML.

## Interface

- `Chunk::Cli.new(argv, env: ENV, out: $stdout, err: $stderr, opener: ...).run` - gives the exit status (0, 1, or 2). `opener` gets the page path. A falsy result prints "could not open" and still gives 0. A `Chunk::Error` or a `SystemCallError` (no `git`, an output directory it cannot write) prints `chunk: <message>` and gives 1. A bad option prints the OptionParser message and the usage, and gives 2.
- `Chunk::Git.new(repo_path).diff(base, head)` - the diff text of `git diff BASE...HEAD`, as valid UTF-8. Raises `Chunk::Error` for an empty or blank ref, and with the git stderr text when git fails.
- `Chunk::Git.new(repo_path).full_diff(base, head)` - the same diff as `diff`, with each line of each changed file as context (`--unified=999999`).
- `Chunk::Git.new(repo_path).toplevel` - the top directory of the repository.
- `Chunk::DiffFile.parse(text)` - one `DiffFile` for each file: `header` (exact git header lines), `rows` (`Row`: `kind`, `old_no`, `new_no`, `text`, `no_newline`), `old_lines`, `new_lines`, and `path` (head path, or base path for a deleted file; git C-style quotes are removed, and the tab that git adds after a name with a space is dropped; a mode-only or rename-only file takes its name from the `rename to` line, or from the second half of the `diff --git` line). A binary, rename-only, or mode-only file has no rows.
- `Chunk::Scopes.finder_for(path, warnings)` - a callable `(lines, line_number) -> Range` for the file type. `Chunk::Scopes::Fixed.new(n)` keeps n lines on each side. `Chunk::Scopes::Indentation` gives the block of the nearest less-indented line above, and `nil` at level 0 (except a closing line at level 0, which gives the block it closes). `Chunk::Scopes::Paragraph` gives the lines between blank lines. A finder raises `Chunk::Scopes::Unreadable` when it cannot read the file.
- `Chunk::HunkBuilder.new(finder).build(diff_file)` - the diff text of one file, with one hunk for each merged scope.
- `Chunk::Page.new(diff_text, title:, warnings: []).to_html` - one HTML document. An empty diff shows "No changes".
- `Chunk::Error` - a failure the user must see. `Cli` prints it and gives 1.

## Invariants

- `HunkBuilder`: an added row uses the new file, and a deleted row uses the old file. Spans that overlap or touch merge into one hunk. A hunk side with no lines starts at the line before it (0 when none). The rebuilt diff applies with `git apply --check` at the merge base (specs check this). A file with no rows passes through unchanged. It builds each line array once, and finds each span end with a binary search: 20,000 changed lines take about 0.1 s (a spec checks under 2 s).
- `DiffFile`: a last line with no newline keeps its `\r`, so a Windows file rebuilds exactly.
- `Scopes.finder_for`: the first non-nil range of the chain wins. All nil gives the changed line only. On `Unreadable`, it adds one warning (`<path>: <message>`) and uses the default chain. Default chain: indentation, then paragraph.
- `Indentation`: a tab moves to the next multiple of 8 columns. A blank changed line uses the next non-blank line below, else the nearest above. The header is the nearest line above with less indentation; for a changed closing line, it is the nearest line above at the same or less indentation (the line it closes). The block runs from the header to the line before the next line with the same or less indentation; that line is in the block when it starts with `end` (not a key such as `end:` or `endpoint:`), `}`, `]`, `)`, or `</`. Trailing blank lines are not in the block.
- `Indentation`, `Paragraph`: each analyzes a file one time and keeps the analysis of the last two files (old and new) through `Scopes::Cached`, so 20,000 changed lines in one block take about 0.2 s.

- `Git` passes `--end-of-options` before the refs, so a ref can never be read as a git option.
- `Git` runs only read commands (`diff`, `rev-parse`). It starts `git` with an argument array, never through a shell.
- `Git` turns off color, external diff tools, and textconv, so the diff matches GitHub.
- `Git` refuses an empty ref, because git reads `...HEAD` as `HEAD...HEAD` and gives a wrong diff with no error.
- `Git` pins the `a/` and `b/` path prefixes, so a user `diff.noprefix` or `diff.mnemonicPrefix` setting does not change the diff text.
- `Git` gives valid UTF-8, in the diff and in its error messages: it replaces each byte that is not UTF-8 with U+FFFD, so a Latin-1 file or a `LANG=C` shell does not stop a later step.
- `Page` escapes each `<` in the embedded diff data as `\u003c`, so no diff text can end the script element.
- `Page` reads its inlined files as UTF-8, so a shell with `LANG=C` still gives a page.
- `Page` holds all CSS and JavaScript inline: `vendor/diff2html`, `page.css`, and `page.js`.
- The page starts in the side-by-side view. The button switches to the inline view and back.
- Page file name: each character outside `[A-Za-z0-9._-]` in the repository name and the refs becomes `-`.

## Side Effects

- `Cli` makes the output directory and writes one HTML file. It starts `open` through the default `opener`.
- `Git` starts `git`.

## Verification

- `bundle exec rspec spec/chunk`
