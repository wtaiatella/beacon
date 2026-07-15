#!/usr/bin/env bash
# PreToolUse (matcher: Write|Edit) — branch governance. Blocks write operations
# whose target file lives inside a child (target) repository that is currently on a
# protected branch (main, master, develop, release/*). The workspace repo itself is
# expected to be on main and is EXCLUDED — only child repos cloned inside the
# workspace are checked.
#
# Cursor original fired on subagentStart and blocked write-capable agents. Claude
# Code has no "readonly subagent" signal, so this port enforces the same policy at
# the actual write: it inspects the file being written/edited and refuses if that
# file's containing child repo is on a protected branch.
#
# Claude Code protocol: reads tool call JSON from stdin (.tool_input.file_path).
# To BLOCK, exit 2 with a reason on stderr. Else exit 0.
ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
export HOOK_ROOT="$ROOT"
export HOOK_INPUT="$(cat)"
node -e '
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const root = process.env.HOOK_ROOT;

let filePath = "";
try {
  const input = JSON.parse(process.env.HOOK_INPUT || "{}");
  filePath = (input.tool_input && input.tool_input.file_path) || "";
} catch (e) {
  process.exit(0); // fail-open
}
if (!filePath) process.exit(0);

// Resolve to absolute path
const abs = path.isAbsolute(filePath) ? filePath : path.resolve(root, filePath);

// Only gate writes that land inside the workspace root
const rel = path.relative(root, abs);
if (rel.startsWith("..") || path.isAbsolute(rel)) process.exit(0); // outside workspace

// The first path segment is the child dir (e.g. "myapp/src/x.ts" -> "myapp")
const seg = rel.split(path.sep)[0];
if (!seg || seg === "") process.exit(0);
const childDir = path.join(root, seg);

// A file written directly at the workspace root (no child dir) is excluded
if (childDir === root) process.exit(0);

// Only check dirs that are their own git repo (have a .git)
if (!fs.existsSync(path.join(childDir, ".git"))) process.exit(0);

function isProtected(b) {
  return b === "main" || b === "master" || b === "develop" || /^release\//.test(b);
}

let branch = "";
try {
  branch = execSync("git rev-parse --abbrev-ref HEAD", { cwd: childDir, encoding: "utf8" }).trim();
} catch (e) {
  process.exit(0); // fail-open if we cannot determine the branch
}

if (branch && isProtected(branch)) {
  const reason =
    "Write blocked — repo \"" + seg + "/\" is on protected branch \"" + branch +
    "\". Switch to a feature branch first: cd " + seg + "/ && git checkout -b feature/my-work";
  process.stderr.write("Blocked by subagent-gate hook: " + reason + "\n");
  process.exit(2);
}
process.exit(0);
'
