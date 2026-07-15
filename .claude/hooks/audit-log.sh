#!/usr/bin/env bash
# SessionEnd — appends a timestamped line to docs/audit.log for a local audit trail.
# Format: TSV — timestamp, session_id, reason, duration_ms, final_status, error_message
# (kept 6-column for compatibility with session-verify's status summary and the
# Cursor port). Claude Code's SessionEnd stdin carries {session_id, transcript_path,
# cwd, reason}; duration_ms / final_status / error_message are Cursor-only and are
# written empty here. Output: none (fire-and-forget).
ROOT="$(cd "$(dirname "$0")"/../.. && pwd)"
export AUDIT_LOG_ROOT="$ROOT"
cat | node -e "
const fs = require('fs');
const root = process.env.AUDIT_LOG_ROOT;
let j = {};
try { j = JSON.parse(fs.readFileSync(0, 'utf8')); } catch (e) { j = {}; }
const ts = new Date().toISOString().replace(/\.\d{3}Z/, 'Z');
const line = [ts, j.session_id ?? '', j.reason ?? '', j.duration_ms ?? '', j.final_status ?? '', j.error_message ?? ''].join('\t');
try {
  fs.mkdirSync(root + '/docs', { recursive: true });
  fs.appendFileSync(root + '/docs/audit.log', line + '\n');
} catch (e) { /* fail-open */ }
"
