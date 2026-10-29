#!/usr/bin/env bash
# audit-log — SessionEnd / sessionEnd: append a TSV line to docs/audit.log.
# Format: ts, session_id, reason, duration_ms, final_status, error_message
# Accepts Claude and Cursor field names (session_id | conversation_id, etc.).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export AUDIT_LOG_ROOT="$ROOT"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat || true)"
node <<'NODE'
const fs = require("fs");
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const j = proto.readInput();
const root = proto.workspaceRootOf(j, process.env.AUDIT_LOG_ROOT);
if (!proto.isBeaconWorkspace(root)) {
  proto.allow(j);
}
const ts = new Date().toISOString().replace(/\.\d{3}Z/, "Z");
const sessionId = proto.sessionIdOf(j);
const reason = j.reason || j.end_reason || "";
const duration = j.duration_ms ?? j.duration ?? "";
const status = j.final_status || j.status || "";
const err = j.error_message || j.error || "";
const line = [ts, sessionId, reason, duration, status, err].join("\t");
try {
  fs.mkdirSync(root + "/docs", { recursive: true });
  fs.appendFileSync(root + "/docs/audit.log", line + "\n");
} catch (e) { /* fail-open */ }
proto.allow(j);
NODE
