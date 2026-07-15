#!/usr/bin/env bash
# PreToolUse (matcher: Bash) — blocks destructive or risky shell commands before
# they execute. Catches catastrophic deletes, force-pushes to protected branches,
# destructive SQL, and other unsafe patterns. Blocked commands are logged to
# docs/audit.log. Registered in .claude/settings.json.
#
# Claude Code protocol: reads the tool call JSON from stdin; the shell command is
# at .tool_input.command. To BLOCK, exit 2 with a reason on stderr (fed back to
# the model). To ALLOW, exit 0 silently.
ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
export HOOK_ROOT="$ROOT"
export HOOK_CWD="$(pwd)"
cat | node -e '
const fs = require("fs");
const root = process.env.HOOK_ROOT;
const cwd = process.env.HOOK_CWD || "";
let cmd = "";
try {
  const input = JSON.parse(fs.readFileSync(0, "utf8"));
  cmd = (input.tool_input && input.tool_input.command) || "";
} catch (e) {
  process.exit(0); // fail-open
}
const c = cmd.replace(/\s+/g, " ").trim();
const lc = c.toLowerCase();

function block(reason) {
  try {
    fs.mkdirSync(root + "/docs", { recursive: true });
    const ts = new Date().toISOString().replace(/\.\d{3}Z/, "Z");
    fs.appendFileSync(root + "/docs/audit.log", ts + "\tshell blocked\t" + reason + "\t" + c + "\n");
  } catch (e) { /* fail-open on logging */ }
  process.stderr.write("Blocked by before-shell hook: " + reason + "\n");
  process.exit(2);
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

process.exit(0);
'
