#!/usr/bin/env bash
# PreToolUse (matcher: Read) — prevents the agent from reading files that likely
# contain secrets (API keys, credentials, private keys). Blocks .env files, *.pem,
# *.key, ~/.ssh/*, ~/.aws/credentials, ~/.kube/config, and paths containing
# /secrets/ or /credentials/. Keeps sensitive data out of agent context.
#
# Claude Code protocol: reads the tool call JSON from stdin; the target path is at
# .tool_input.file_path. To BLOCK, exit 2 with a reason on stderr. Else exit 0.
export HOOK_HOME="$HOME"
cat | node -e '
const fs = require("fs");
const homedir = process.env.HOOK_HOME || require("os").homedir();
let raw = "";
try {
  const input = JSON.parse(fs.readFileSync(0, "utf8"));
  raw = (input.tool_input && input.tool_input.file_path) || "";
} catch (e) {
  process.exit(0); // fail-open
}
if (!raw) process.exit(0);
let p = raw.replace(/^~(?=\/)/, homedir);
const norm = p.replace(/\\/g, "/");
const base = norm.split("/").pop() || "";
const reason = "Potential secrets file -- reading this would expose sensitive data in the agent context.";

function block() {
  process.stderr.write("Blocked by before-read hook: " + reason + "\n");
  process.exit(2);
}

if (base === ".env" || /^\.env\./i.test(base)) block();
if (/credentials/i.test(base) || /secrets/i.test(base) || /private_key/i.test(base)) block();
if (/\.pem$/i.test(base) || /\.key$/i.test(base)) block();
if (norm.startsWith(homedir + "/.ssh/")) block();
if (norm === homedir + "/.aws/credentials" || norm.startsWith(homedir + "/.aws/credentials/")) block();
if (norm === homedir + "/.kube/config" || norm.startsWith(homedir + "/.kube/config/")) block();
if (/\/secrets\//i.test(norm) || /\/credentials\//i.test(norm)) block();

process.exit(0);
'
