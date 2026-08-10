#!/usr/bin/env bash
# tool-audit — append a per-tool audit row for Claude Code and Cursor.
# This hook is intentionally fail-open and emits no stdout, so it never changes
# tool behavior. It records only small, bounded summaries (no full stdout).
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export HOOK_DIR="$DIR"
export HOOK_ROOT="$ROOT"
export HOOK_INPUT="$(cat || true)"

node <<'NODE'
const fs = require("fs");
const path = require("path");
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");

const root = process.env.HOOK_ROOT;
const input = proto.readInput();

function truncate(s, max) {
  s = String(s || "").replace(/\s+/g, " ").trim();
  return s.length > max ? s.slice(0, max - 3) + "..." : s;
}

function tsv(s) {
  return String(s ?? "")
    .replace(/\t/g, " ")
    .replace(/\r?\n/g, " ")
    .trim();
}

function safeSegment(s) {
  return String(s || "unknown")
    .replace(/[^A-Za-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 160) || "unknown";
}

function activeSessionFallback() {
  try {
    const p = path.join(root, "docs", "sessions", "ACTIVE_SESSION");
    return fs.readFileSync(p, "utf8").trim();
  } catch (_) {
    return "";
  }
}

function statusOf(j) {
  if (j.failure_type) return String(j.failure_type);
  if (j.error_message || j.error) return "error";
  if (j.permission === "deny") return "denied";
  return "ok";
}

function eventOf(j) {
  return (
    j.hook_event_name ||
    j.hookEventName ||
    j.event ||
    (j.failure_type || j.error_message ? "postToolUseFailure" : "postToolUse")
  );
}

function summaryOf(j) {
  const ti = proto.toolInput(j);
  const command = proto.commandOf(j);
  if (command) return "cmd=" + truncate(command, 190);
  const filePath = proto.filePathOf(j);
  if (filePath) return "file=" + truncate(filePath, 190);
  if (ti.subagent_type || ti.subagentType) {
    return "subagent=" + truncate(ti.subagent_type || ti.subagentType, 190);
  }
  if (j.tool_use_id || j.toolUseId) return "tool_use_id=" + truncate(j.tool_use_id || j.toolUseId, 190);
  if (j.error_message || j.error) return "error=" + truncate(j.error_message || j.error, 190);
  return "";
}

try {
  const ts = new Date().toISOString().replace(/\.\d{3}Z/, "Z");
  const ide = proto.ideOf(input);
  const session = proto.sessionIdOf(input) || activeSessionFallback() || "unknown";
  const event = eventOf(input);
  const tool = proto.toolNameOf(input);
  const status = statusOf(input);
  const duration = proto.durationOf(input);
  const summary = truncate(summaryOf(input), 200);

  const dir = path.join(root, "docs", "local");
  const seqDir = path.join(dir, "tool-audit-seq");
  fs.mkdirSync(seqDir, { recursive: true });

  const seqPath = path.join(seqDir, safeSegment(ide + "-" + session) + ".seq");
  let seq = 0;
  try {
    seq = parseInt(fs.readFileSync(seqPath, "utf8").trim(), 10) || 0;
  } catch (_) {}
  seq += 1;
  fs.writeFileSync(seqPath, String(seq) + "\n");

  const auditPath = path.join(dir, "tool-audit.tsv");
  const header = "ts\tseq\tide\tsession_id\tevent\ttool\tstatus\tduration_ms\tsummary\n";
  if (!fs.existsSync(auditPath) || fs.statSync(auditPath).size === 0) {
    fs.writeFileSync(auditPath, header);
  }

  const row = [
    ts,
    seq,
    ide,
    session,
    event,
    tool,
    status,
    duration,
    summary,
  ].map(tsv).join("\t") + "\n";
  fs.appendFileSync(auditPath, row);
} catch (_) {
  // fail-open
}
NODE
