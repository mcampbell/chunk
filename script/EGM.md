# script

## Overview

`ts_scopes.mjs` finds the function and class ranges of a TypeScript or JavaScript file for `Chunk::Scopes::Typescript`. It uses the `typescript` package 6.x from `package.json` (run `npm ci`).

## Interface

- `node script/ts_scopes.mjs <file-name> < source` - prints a JSON array of `{"kind": "function" | "class", "start": n, "end": m}`, with 1-based lines. The extension of `<file-name>` picks the syntax: `.ts` TypeScript, `.tsx` TSX, `.js`, `.mjs`, `.cjs` JavaScript, `.jsx` JSX.
- Exit status 1, with one error message for each line on stderr (no file name in front), for a syntax error.

## Invariants

- A function is a function declaration, a method, a constructor, a get or set accessor, or a function or arrow function stored in a named variable, class field, or object property, or by an assignment such as `module.exports.f = function () {}`. An anonymous callback, such as `items.map(x => ...)`, is not a function: it is part of the function around it.
- A class is a class declaration or a class expression.
- A range starts at the JSDoc comment above the function or class, when it has one.
- The package is pinned to `typescript` 6.x: the 7.x package (7.0.2, 2026-11-20) has its AST API only under `typescript/unstable/*`.
- The script reads the syntax errors from `sourceFile.parseDiagnostics` (internal API). If a later 6.x removes it, the script uses `ts.transpileModule` diagnostics.

## Side Effects

- None. It reads stdin and writes stdout and stderr.

## Verification

- `node script/ts_scopes.mjs sample.ts < spec/fixtures/ts/sample.ts | diff - spec/fixtures/ts/sample.expected.json`
- `bundle exec rspec spec/chunk/scopes/typescript_spec.rb`
