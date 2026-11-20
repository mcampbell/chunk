// Usage: node script/ts_scopes.mjs <file-name> < source
// Prints a JSON array of {kind, start, end} (1-based lines) for functions and classes.
import ts from "typescript";
import { readFileSync } from "node:fs";
import { extname } from "node:path";

const fileName = process.argv[2];
const source = readFileSync(0, "utf8");
const kinds = { ".ts": ts.ScriptKind.TS, ".tsx": ts.ScriptKind.TSX, ".js": ts.ScriptKind.JS, ".jsx": ts.ScriptKind.JSX, ".mjs": ts.ScriptKind.JS, ".cjs": ts.ScriptKind.JS };
const sf = ts.createSourceFile(fileName, source, ts.ScriptTarget.Latest, true, kinds[extname(fileName)]);

// parseDiagnostics is internal API; fall back to transpileModule if it goes away.
/** @type {readonly ts.Diagnostic[]} */
const diagnostics = /** @type {any} */ (sf).parseDiagnostics ??
  ts.transpileModule(source, { reportDiagnostics: true, fileName }).diagnostics ?? [];
// Exit code, not process.exit(), so Node writes all of stderr before it stops.
if (diagnostics.length) {
  for (const d of diagnostics) console.error(ts.flattenDiagnosticMessageText(d.messageText, "\n"));
  process.exitCode = 1;
}

/** @param {ts.Node} n @returns {"function" | "class" | undefined} */
const kindOf = (n) => {
  if (ts.isClassDeclaration(n) || ts.isClassExpression(n)) return "class";
  if (ts.isFunctionDeclaration(n) || ts.isMethodDeclaration(n) || ts.isConstructorDeclaration(n) ||
      ts.isGetAccessorDeclaration(n) || ts.isSetAccessorDeclaration(n)) return "function";
  const p = n.parent;
  if ((ts.isFunctionExpression(n) || ts.isArrowFunction(n)) &&
      (((ts.isVariableDeclaration(p) || ts.isPropertyDeclaration(p) || ts.isPropertyAssignment(p)) &&
        p.name) ||
       // module.exports.f = function () {}, or x = () => {}
       (ts.isBinaryExpression(p) && p.operatorToken.kind === ts.SyntaxKind.EqualsToken && p.right === n)))
    return "function";
};

/** @param {number} pos */
const line = (pos) => sf.getLineAndCharacterOfPosition(pos).line + 1;
/** @type {{kind: string, start: number, end: number}[]} */
const out = [];
/** @param {ts.Node} n */
const visit = (n) => {
  const kind = kindOf(n);
  // getStart with true includes the JSDoc comment above the node.
  if (kind) out.push({ kind, start: line(n.getStart(sf, true)), end: line(n.getEnd()) });
  ts.forEachChild(n, visit);
};
if (!diagnostics.length) {
  visit(sf);
  console.log(JSON.stringify(out));
}
