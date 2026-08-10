#!/usr/bin/env bash
# before-read — blocks reading likely-secret files (Claude PreToolUse Read or
# Cursor beforeReadFile). Dual protocol via lib/hook-protocol.js.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export HOOK_HOME="${HOME:-}"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat || true)"
node <<'NODE'
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const homedir = process.env.HOOK_HOME || require("os").homedir();
const input = proto.readInput();
const raw = proto.filePathOf(input);
if (!raw) proto.allow(input);

let p = raw.replace(/^~(?=\/)/, homedir);
const norm = p.replace(/\\/g, "/");
const base = norm.split("/").pop() || "";
const reason =
  "Blocked by before-read hook: Potential secrets file -- reading this would expose sensitive data in the agent context.";

function block() {
  proto.deny(input, reason);
}

if (base === ".env" || /^\.env\./i.test(base)) block();
if (/credentials/i.test(base) || /secrets/i.test(base) || /private_key/i.test(base)) block();
if (/\.pem$/i.test(base) || /\.key$/i.test(base)) block();
if (norm.startsWith(homedir + "/.ssh/")) block();
if (norm === homedir + "/.aws/credentials" || norm.startsWith(homedir + "/.aws/credentials/")) block();
if (norm === homedir + "/.kube/config" || norm.startsWith(homedir + "/.kube/config/")) block();
if (/\/secrets\//i.test(norm) || /\/credentials\//i.test(norm)) block();

proto.allow(input);
NODE
