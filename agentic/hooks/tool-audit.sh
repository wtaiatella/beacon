#!/usr/bin/env bash
# tool-audit — action-level audit for Claude Code and Cursor.
#
# Default: append one action row when a Task/subagent completion is observed.
# Detail mode: also append one row per tool event to docs/local/tool-audit.tsv.
#
# Enable detail mode with either:
#   TOOL_AUDIT_DETAIL=1 claude
#   export TOOL_AUDIT_DETAIL=1
#   touch docs/local/TOOL_AUDIT_DETAIL
#
# This hook is intentionally fail-open and emits no stdout.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
RUNTIME_HINT=""
case "$DIR" in
  *"/.claude/hooks") RUNTIME_HINT="claude" ;;
  *"/.cursor/hooks") RUNTIME_HINT="cursor" ;;
esac

export HOOK_DIR="$DIR"
export HOOK_ROOT="$ROOT"
export HOOK_RUNTIME_HINT="$RUNTIME_HINT"
export HOOK_INPUT="$(cat || true)"

node <<'NODE'
const fs = require('fs');
const path = require('path');
const proto = require(process.env.HOOK_DIR + '/lib/hook-protocol');

const root = process.env.HOOK_ROOT;
const runtimeHint = process.env.HOOK_RUNTIME_HINT || '';
const input = proto.readInput();

function truncate(s, max) {
  s = String(s || '').replace(/\s+/g, ' ').trim();
  return s.length > max ? s.slice(0, max - 3) + '...' : s;
}

function tsv(s) {
  return String(s ?? '')
    .replace(/\t/g, ' ')
    .replace(/\r?\n/g, ' ')
    .trim();
}

function safeSegment(s) {
  return (
    String(s || 'unknown')
      .replace(/[^A-Za-z0-9._-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 160) || 'unknown'
  );
}

function activeSessionFallback() {
  try {
    return fs
      .readFileSync(path.join(root, 'docs', 'sessions', 'ACTIVE_SESSION'), 'utf8')
      .trim();
  } catch (_) {
    return '';
  }
}

function statusOf(j) {
  if (j.failure_type) return String(j.failure_type);
  if (j.error_message || j.error) return 'error';
  if (j.permission === 'deny') return 'denied';
  return 'ok';
}

function eventOf(j) {
  return (
    j.hook_event_name ||
    j.hookEventName ||
    j.event ||
    (j.failure_type || j.error_message ? 'postToolUseFailure' : 'postToolUse')
  );
}

function summaryOf(j) {
  const ti = proto.toolInput(j);
  const command = proto.commandOf(j);
  if (command) return 'cmd=' + truncate(command, 190);
  const filePath = proto.filePathOf(j);
  if (filePath) return 'file=' + truncate(filePath, 190);
  if (ti.subagent_type || ti.subagentType) {
    return 'subagent=' + truncate(ti.subagent_type || ti.subagentType, 190);
  }
  if (j.tool_use_id || j.toolUseId) {
    return 'tool_use_id=' + truncate(j.tool_use_id || j.toolUseId, 190);
  }
  if (j.error_message || j.error) return 'error=' + truncate(j.error_message || j.error, 190);
  return '';
}

function parseMaybeJson(v) {
  if (!v || typeof v !== 'string') return null;
  const s = v.trim();
  if (!s || !/^[\[{]/.test(s)) return null;
  try {
    return JSON.parse(s);
  } catch (_) {
    return null;
  }
}

function collectTokens(obj, out) {
  if (!obj || typeof obj !== 'object') return;
  if (Array.isArray(obj)) {
    for (const item of obj) collectTokens(item, out);
    return;
  }
  for (const [k, v] of Object.entries(obj)) {
    const lk = String(k).toLowerCase();
    if (typeof v === 'number' && lk.includes('token')) {
      if (lk.includes('total')) out.total = Math.max(out.total || 0, Math.round(v));
      else if (lk.includes('prompt') || lk.includes('input')) out.in = Math.max(out.in || 0, Math.round(v));
      else if (lk.includes('completion') || lk.includes('output')) out.out = Math.max(out.out || 0, Math.round(v));
    } else if (lk === 'usage' && v && typeof v === 'object') {
      collectTokens(v, out);
    } else if (typeof v === 'string') {
      const parsed = parseMaybeJson(v);
      if (parsed) collectTokens(parsed, out);
    } else if (v && typeof v === 'object') {
      collectTokens(v, out);
    }
  }
}

function tokensFromTranscript(transcriptPath) {
  if (!transcriptPath) return null;
  try {
    const st = fs.statSync(transcriptPath);
    const max = 2 * 1024 * 1024;
    const start = Math.max(0, st.size - max);
    const fd = fs.openSync(transcriptPath, 'r');
    const buf = Buffer.alloc(st.size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    fs.closeSync(fd);
    const lines = buf.toString('utf8').split(/\r?\n/).filter(Boolean).slice(-400);
    let last = null;
    for (const line of lines) {
      const parsed = parseMaybeJson(line);
      if (!parsed) continue;
      const found = {};
      collectTokens(parsed, found);
      if (found.total || found.in || found.out) last = found;
    }
    return last;
  } catch (_) {
    return null;
  }
}

function tokenInfo(j) {
  const payload = {};
  collectTokens(j, payload);
  if (payload.total || payload.in || payload.out) return { ...payload, source: 'payload' };
  const transcript = tokensFromTranscript(j.transcript_path || j.transcriptPath);
  if (transcript) return { ...transcript, source: 'transcript' };
  return { total: '', in: '', out: '', source: 'none' };
}

function explicitActionOf(j) {
  const ti = proto.toolInput(j);
  const subagent = ti.subagent_type || ti.subagentType || j.subagent_type || j.subagentType;
  if (subagent) return String(subagent);

  const candidates = [proto.filePathOf(j), proto.commandOf(j), summaryOf(j)].filter(Boolean);
  for (const text of candidates) {
    const s = String(text);
    const m =
      s.match(/(?:^|\/)\.(?:claude|cursor)\/agents\/([^/\s]+)\.md\b/) ||
      s.match(/(?:^|\/)\.(?:claude|cursor)\/commands\/([^/\s]+)\.md\b/) ||
      s.match(/(?:^|\/)\.agents\/skills\/([^/\s]+)\/SKILL\.md\b/) ||
      s.match(/(?:^|\/)\.claude\/skills\/([^/\s]+)\/SKILL\.md\b/) ||
      s.match(/\/(bcs-[a-z0-9-]+|prd|spectech|tasks|dev|sre|data|qa|run|summary|scrum|fix|do)\b/);
    if (m && m[1]) return m[1];
  }
  return '';
}

function readCurrentAction(stateDir, ide, session) {
  try {
    return fs.readFileSync(path.join(stateDir, safeSegment(ide + '-' + session) + '.action'), 'utf8').trim();
  } catch (_) {
    return '';
  }
}

function writeCurrentAction(stateDir, ide, session, action) {
  if (!action) return;
  fs.writeFileSync(path.join(stateDir, safeSegment(ide + '-' + session) + '.action'), action + '\n');
}

function isActionCompletion(j, tool, event, explicitAction) {
  if (!explicitAction) return false;
  if (tool === 'Task' || tool === 'Subagent') return true;
  return /subagentStop|TaskStop|taskStop/i.test(String(event));
}

function detailEnabled(dir) {
  if (process.env.TOOL_AUDIT_DETAIL === '1') return true;
  return fs.existsSync(path.join(dir, 'TOOL_AUDIT_DETAIL'));
}

function appendTsv(file, header, row) {
  if (!fs.existsSync(file) || fs.statSync(file).size === 0) {
    fs.writeFileSync(file, header);
  } else {
    const firstLine = fs.readFileSync(file, 'utf8').split(/\r?\n/, 1)[0] + '\n';
    if (firstLine !== header) {
      const legacy = file.replace(/\.tsv$/, '') + '.legacy-' + Date.now() + '.tsv';
      fs.renameSync(file, legacy);
      fs.writeFileSync(file, header);
    }
  }
  fs.appendFileSync(file, row.map(tsv).join('\t') + '\n');
}

function nextSeq(seqDir, key) {
  const seqPath = path.join(seqDir, safeSegment(key) + '.seq');
  let seq = 0;
  try {
    seq = parseInt(fs.readFileSync(seqPath, 'utf8').trim(), 10) || 0;
  } catch (_) {}
  seq += 1;
  fs.writeFileSync(seqPath, String(seq) + '\n');
  return seq;
}

try {
  const ts = new Date().toISOString().replace(/\.\d{3}Z/, 'Z');
  const ide = proto.ideOf(input, runtimeHint);
  const session = proto.sessionIdOf(input) || activeSessionFallback() || 'unknown';
  const event = eventOf(input);
  const tool = proto.toolNameOf(input);
  const status = statusOf(input);
  const duration = proto.durationOf(input);
  const summary = truncate(summaryOf(input), 200);

  const dir = path.join(root, 'docs', 'local');
  const seqDir = path.join(dir, 'tool-audit-seq');
  const stateDir = path.join(dir, 'tool-audit-state');
  fs.mkdirSync(seqDir, { recursive: true });
  fs.mkdirSync(stateDir, { recursive: true });

  const explicitAction = explicitActionOf(input);
  if (explicitAction) writeCurrentAction(stateDir, ide, session, explicitAction);
  const action = explicitAction || readCurrentAction(stateDir, ide, session) || 'unknown';

  if (detailEnabled(dir)) {
    const seq = nextSeq(seqDir, ide + '-' + session + '-detail');
    appendTsv(
      path.join(dir, 'tool-audit.tsv'),
      'ts\tseq\tide\tsession_id\taction\tevent\ttool\tstatus\tduration_ms\tsummary\n',
      [ts, seq, ide, session, action, event, tool, status, duration, summary]
    );
  }

  if (isActionCompletion(input, tool, event, explicitAction)) {
    const tokens = tokenInfo(input);
    appendTsv(
      path.join(dir, 'action-audit.tsv'),
      'ts\tide\tsession_id\taction\tevent\tstatus\tduration_ms\ttokens_total\ttokens_in\ttokens_out\ttoken_source\tsummary\n',
      [
        ts,
        ide,
        session,
        explicitAction,
        event,
        status,
        duration,
        tokens.total || '',
        tokens.in || '',
        tokens.out || '',
        tokens.source || 'none',
        summary || 'subagent=' + explicitAction,
      ]
    );
  }
} catch (_) {
  // fail-open
}
NODE
