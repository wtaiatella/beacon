#!/usr/bin/env bash
# subagent-gate — blocks writes into a child repo that is on a protected branch
# (main, master, develop, release/*). Workspace root is excluded.
#
# Claude: PreToolUse matcher Write|Edit|MultiEdit
# Cursor: preToolUse matcher Write (and afterFileEdit cannot block)
#
# Dual protocol via lib/hook-protocol.js.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export HOOK_FALLBACK_ROOT="$ROOT"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat)"
node <<'NODE'
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
let input = proto.readInput();
const root = proto.workspaceRootOf(input, process.env.HOOK_FALLBACK_ROOT);
if (!proto.isBeaconWorkspace(root)) proto.allow(input);
const filePath = proto.filePathOf(input);
if (!filePath) proto.allow(input);

const abs = path.isAbsolute(filePath) ? filePath : path.resolve(root, filePath);
const rel = path.relative(root, abs);
if (rel.startsWith("..") || path.isAbsolute(rel)) proto.allow(input);

const seg = rel.split(path.sep)[0];
if (!seg) proto.allow(input);
const childDir = path.join(root, seg);
if (childDir === root) proto.allow(input);
if (!fs.existsSync(path.join(childDir, ".git"))) proto.allow(input);

function isProtected(b) {
  return b === "main" || b === "master" || b === "develop" || /^release\//.test(b);
}

let branch = "";
try {
  branch = execSync("git rev-parse --abbrev-ref HEAD", {
    cwd: childDir,
    encoding: "utf8",
  }).trim();
} catch (e) {
  proto.allow(input);
}

if (branch && isProtected(branch)) {
  const reason =
    'Write blocked — repo "' +
    seg +
    '/" is on protected branch "' +
    branch +
    '". Switch to a feature branch first: cd ' +
    seg +
    "/ && git checkout -b feature/my-work";
  proto.deny(input, "Blocked by subagent-gate hook: " + reason);
}
proto.allow(input);
NODE
