#!/usr/bin/env bash
# before-shell — blocks destructive/risky shell commands (Claude PreToolUse Bash
# or Cursor beforeShellExecution). Fail-open on parse errors.
#
# Dual protocol via lib/hook-protocol.js (Claude exit-2 vs Cursor permission JSON).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export HOOK_ROOT="$ROOT"
export HOOK_CWD="$(pwd)"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat || true)"
node <<'NODE'
const fs = require("fs");
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const input = proto.readInput();
const root = proto.workspaceRootOf(input, process.env.HOOK_ROOT);
const cwd = proto.cwdOf(input, process.env.HOOK_CWD || "");
const cmd = proto.commandOf(input);
if (!cmd) proto.allow(input);

const c = cmd.replace(/\s+/g, " ").trim();
const lc = c.toLowerCase();

function block(reason) {
  try {
    fs.mkdirSync(root + "/docs", { recursive: true });
    const ts = new Date().toISOString().replace(/\.\d{3}Z/, "Z");
    fs.appendFileSync(root + "/docs/audit.log", ts + "\tshell blocked\t" + reason + "\t" + c + "\n");
  } catch (e) { /* fail-open on logging */ }
  proto.deny(input, "Blocked by before-shell hook: " + reason);
}

if (/rm\s+-rf\s+\/(?:\s|$)/.test(c) || /rm\s+-rf\s+~(?:\/|\s|$)/.test(c)) {
  block("Catastrophic delete (rm -rf / or ~)");
}
if (cwd === root && /rm\s+-rf\s+\.\s*$/.test(c)) {
  block("rm -rf . at workspace root");
}

if (/\bgit\s+push\b/.test(c) && (/\s--force\b/.test(c) || /(^|\s)-f(\s|$)/.test(c))) {
  const tokens = c.split(/\s+/);
  const prot = (t) => ["main", "master", "develop"].includes(t) || /^release\//.test(t);
  if (tokens.some(prot)) block("Force push to protected branch");
}
if (/git\s+branch\s+-D\s+(main|master|develop)\b/.test(c)) {
  block("Delete protected branch");
}

if (/drop\s+table\b|drop\s+database\b|truncate\s+table\b/.test(lc)) {
  block("Destructive SQL");
}
if (/chmod\s+777\b/.test(c)) block("Overly permissive chmod 777");
if (c.includes(":(){ :|:& };:")) block("Fork bomb");

proto.allow(input);
NODE
