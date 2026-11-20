# chunk

`chunk` shows the diff between two git refs as one HTML page, in the style of a GitHub pull request diff.

The page works offline. A button changes the view between side by side and inline.

Status: each change shows the indentation block that holds it, for example the parent key in YAML or the CSS rule. A change at indentation level 0 shows its paragraph (the lines between blank lines). Changes near each other join into one hunk. Later versions show the complete Ruby method and the complete TypeScript or JavaScript function.

## Requirements

- Ruby 3.4 or later
- git 2.24 or later (for `--end-of-options`)
- macOS `open`, to open the page

## Usage

```sh
bin/chunk [--repo PATH] BASE HEAD
```

- `BASE`, `HEAD`: branch names, tags, or commit SHAs. The diff starts at the merge base of `BASE` and `HEAD` (`git diff BASE...HEAD`), as a GitHub pull request diff does.
- `--repo PATH`: the repository. Default: the current directory.

The command writes `~/tmp/chunk/<repo>-<base>-<head>.html`, prints the path, and opens the page. Each character outside `A-Z`, `a-z`, `0-9`, `.`, `_`, and `-` in the file name becomes `-`.

Exit status:

- `0`: the page is written. This is also true when `open` fails. Then the command prints a warning.
- `1`: an error, for example an unknown ref, a path that is not a repository, or an output directory that the command cannot write.
- `2`: wrong usage.

The command reads git objects only. It does not change your working tree or your index.

## Configuration

- `CHUNK_OUTPUT_DIR`: the directory for the page. Default: `~/tmp/chunk`.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```
