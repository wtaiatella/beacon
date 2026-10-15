#!/usr/bin/env bash
# session-verify — SessionEnd / sessionEnd companion: warn on secrets churn,
# security markers, non-executable hooks, and review-status specs with open tasks.
# Never blocks. Checks both .claude/hooks and .cursor/hooks for executability.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export SESSION_VERIFY_ROOT="$ROOT"
export SESSION_VERIFY_INPUT="$(cat || true)"
node <<'NODE'
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
let input = {};
try {
  input = JSON.parse(process.env.SESSION_VERIFY_INPUT || "{}");
} catch (e) { /* session payload optional */ }
const root = proto.workspaceRootOf(input, process.env.SESSION_VERIFY_ROOT);
const warnings = [];

function sh(cmd, opts) {
  try {
    return execSync(cmd, { encoding: "utf8", maxBuffer: 2 * 1024 * 1024, ...opts });
  } catch (e) {
    return "";
  }
}

const auditLog = path.join(root, "docs", "audit.log");
if (fs.existsSync(auditLog)) {
  const envNew = sh(`find . -maxdepth 3 -name ".env*" -newer docs/audit.log 2>/dev/null`, { cwd: root });
  if (envNew.trim()) {
    warnings.push(
      "New or updated .env files under workspace since last audit log write: " +
        envNew.trim().split(/\n/).slice(0, 5).join(", ")
    );
  }
}

const recent = sh(
  `find . \\( -path ./node_modules -o -path ./.git \\) -prune -o -type f -mtime -2 -print 2>/dev/null | head -200`,
  { cwd: root }
);
const files = recent.trim().split(/\n/).filter(Boolean);
const markerRe = /TODO:\s*REMOVE|FIXME:\s*SECURITY/i;
for (const rel of files) {
  const fp = path.join(root, rel);
  try {
    const data = fs.readFileSync(fp, "utf8");
    if (markerRe.test(data)) warnings.push("Security marker in recent file: " + rel);
  } catch (e) { /* skip */ }
}

function checkHookDir(relDir) {
  const hookDir = path.join(root, relDir);
  try {
    for (const name of fs.readdirSync(hookDir)) {
      if (!name.endsWith(".sh")) continue;
      const hp = path.join(hookDir, name);
      const st = fs.statSync(hp);
      if ((st.mode & 0o111) === 0) warnings.push("Hook script not executable: " + relDir + "/" + name);
    }
  } catch (e) { /* skip missing dir */ }
}
checkHookDir(".claude/hooks");
checkHookDir(".cursor/hooks");

const specsDir = path.join(root, "docs", "specs");
try {
  for (const name of fs.readdirSync(specsDir)) {
    if (!name.endsWith(".md")) continue;
    const fp = path.join(specsDir, name);
    const text = fs.readFileSync(fp, "utf8");
    const fm = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    if (!fm) continue;
    const statusLine = fm[1].split(/\r?\n/).find((l) => /^status:\s*/i.test(l));
    if (!statusLine || !/^status:\s*review\s*$/i.test(statusLine.trim())) continue;
    if (/^-\s+\[\s+\]\s/m.test(text)) {
      warnings.push("Spec " + name + " has status review but still has unchecked tasks.");
    }
  }
} catch (e) { /* no specs dir */ }

const statusSummary = {};
try {
  const logData = fs.readFileSync(auditLog, "utf8").trim();
  if (logData) {
    for (const row of logData.split(/\n/)) {
      const cols = row.split("\t");
      if (cols.length < 5) continue;
      const status = (cols[4] || "").trim();
      if (status) {
        statusSummary[status] = (statusSummary[status] || 0) + 1;
      }
    }
  }
  const statuses = Object.keys(statusSummary);
  if (statuses.length > 0) {
    const parts = statuses.map((s) => s + ": " + statusSummary[s]);
    warnings.push("Session status summary: " + parts.join(", "));
  }
} catch (e) { /* no audit log or parse error */ }

if (warnings.length) {
  process.stderr.write("session-verify warnings:\n- " + warnings.join("\n- ") + "\n");
}
NODE
