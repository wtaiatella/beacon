#!/usr/bin/env bash
# Rebuild Cursor chat-centric audit from parent (+ optional subagent) transcripts.
# Usage: scripts/tools/tool-audit-backfill.sh [--ide cursor] [session-id]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDE="cursor"
FILTER=""

usage() {
  cat <<'EOF'
Usage: scripts/tools/tool-audit-backfill.sh [--ide cursor] [session-id]

Rebuilds docs/local/audit-cursor/<session>/ from Cursor agent transcripts.
With no session-id, rebuilds every known parent transcript under the project.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ide)
      IDE="${2:-}"
      shift 2
      ;;
    --ide=*)
      IDE="${1#--ide=}"
      shift
      ;;
    *)
      FILTER="$1"
      shift
      ;;
  esac
done

if [[ "$IDE" != "cursor" ]]; then
  echo "tool-audit-backfill: only --ide cursor is implemented (got '$IDE')" >&2
  exit 1
fi

export TOOL_AUDIT_ROOT="$ROOT"
export TOOL_AUDIT_FILTER="$FILTER"

node <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.env.TOOL_AUDIT_ROOT;
const filter = process.env.TOOL_AUDIT_FILTER || '';

function cursorProjectHash(workspaceRoot) {
  return String(workspaceRoot || '')
    .replace(/^\/+/, '')
    .replace(/[/.]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function transcriptsRoot() {
  return path.join(
    process.env.HOME || '',
    '.cursor',
    'projects',
    cursorProjectHash(root),
    'agent-transcripts'
  );
}

function safeSegment(s) {
  return (
    String(s || 'unknown')
      .replace(/[^A-Za-z0-9._-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 160) || 'unknown'
  );
}

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z/, 'Z');
}

function truncate(s, max) {
  s = String(s || '').replace(/\s+/g, ' ').trim();
  return s.length > max ? s.slice(0, max - 3) + '...' : s;
}

function parseMaybeJson(line) {
  try {
    return JSON.parse(line);
  } catch (_) {
    return null;
  }
}

function collectTextChars(obj) {
  if (typeof obj === 'string') return obj.trim() ? obj.length : 0;
  if (!obj || typeof obj !== 'object') return 0;
  if (Array.isArray(obj)) return obj.reduce((sum, item) => sum + collectTextChars(item), 0);
  let total = 0;
  for (const [k, v] of Object.entries(obj)) {
    const lk = String(k).toLowerCase();
    if (lk === 'id' || lk.endsWith('_id') || lk === 'timestamp' || lk === 'tool_use_id') continue;
    total += collectTextChars(v);
  }
  return total;
}

function estimateTokensFromChars(chars) {
  const n = Number(chars) || 0;
  return n > 0 ? Math.max(1, Math.round(n / 4)) : 0;
}

function readRecords(file) {
  if (!fs.existsSync(file)) return [];
  return fs
    .readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .map(parseMaybeJson)
    .filter(Boolean);
}

function extractUserText(rec) {
  const msg = rec.message || rec;
  const content = msg.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part.text === 'string') return part.text;
        return '';
      })
      .filter(Boolean)
      .join('\n');
  }
  return '';
}

function stripUserQueryWrapper(text) {
  const s = String(text || '');
  const m = s.match(/<user_query>\s*([\s\S]*?)\s*<\/user_query>/i);
  if (m) return m[1].trim();
  return s.replace(/<\/?timestamp[^>]*>/gi, '').trim();
}

function turnIdFromPrompt(prompt, index) {
  const h = crypto
    .createHash('sha1')
    .update(String(index) + '\n' + String(prompt || '').slice(0, 500))
    .digest('hex')
    .slice(0, 12);
  return 't' + index + '-' + h;
}

function turnsFromParent(file) {
  const records = readRecords(file);
  const turns = [];
  let current = null;
  let index = 0;
  function close() {
    if (!current) return;
    current.tokens_est = estimateTokensFromChars(current._chars);
    current.duration_ms = Math.max(
      0,
      (Date.parse(current.end_ts) || 0) - (Date.parse(current.start_ts) || 0)
    );
    delete current._chars;
    turns.push(current);
    current = null;
  }
  for (const rec of records) {
    const role = String(rec.role || '').toLowerCase();
    const chars = collectTextChars(rec);
    if (role === 'user') {
      close();
      index += 1;
      const prompt = stripUserQueryWrapper(extractUserText(rec));
      current = {
        turn_id: turnIdFromPrompt(prompt, index),
        index,
        start_ts: nowIso(),
        end_ts: nowIso(),
        status: 'closed',
        prompt_preview: truncate(prompt, 160),
        tokens_est: 0,
        token_source: 'transcript_estimate',
        duration_ms: 0,
        tool_events: 0,
        tool_errors: 0,
        action_ids: [],
        _chars: chars,
      };
    } else if (current) {
      current._chars += chars;
    }
  }
  close();
  return turns;
}

function estimateFile(file) {
  let chars = 0;
  for (const rec of readRecords(file)) chars += collectTextChars(rec);
  return estimateTokensFromChars(chars);
}

function listParentSessions() {
  const base = transcriptsRoot();
  const out = [];
  if (!fs.existsSync(base)) return out;
  for (const entry of fs.readdirSync(base, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const sid = entry.name;
    const parent = path.join(base, sid, sid + '.jsonl');
    if (fs.existsSync(parent)) out.push({ session: sid, file: parent });
  }
  return out;
}

function rebuild(session, parentFile) {
  const dir = path.join(root, 'docs', 'local', 'audit-cursor', safeSegment(session));
  fs.mkdirSync(dir, { recursive: true });

  const turns = turnsFromParent(parentFile);
  const actions = [];
  const subDir = path.join(path.dirname(parentFile), 'subagents');
  if (fs.existsSync(subDir)) {
    for (const name of fs.readdirSync(subDir)) {
      if (!name.endsWith('.jsonl')) continue;
      const id = name.replace(/\.jsonl$/, '');
      const file = path.join(subDir, name);
      const st = fs.statSync(file);
      const first = readRecords(file)[0];
      const text = first ? stripUserQueryWrapper(extractUserText(first)) : '';
      // Prefer explicit markers only — short tokens like fix/data match branch names / prose.
      let action = 'subagent';
      const markers = [
        /subagent_type["']?\s*[:=]\s*["']([A-Za-z0-9._-]+)/i,
        /\b(beacon-ticket-intake|beacon-repro|beacon-sandbox|beacon-proof|security-scanner|plan-reviewer|dev-reviewer|pre-plan-triage)\b/i,
        /\bTask\((prd|spectech|tasks|dev|sre|data|qa|scrum|do|fix|summary)\)/i,
      ];
      for (const re of markers) {
        const m = text.match(re);
        if (m) {
          action = (m[1] || m[0]).toLowerCase();
          break;
        }
      }
      // turn_id left empty on backfill — live hook attributes via sticky turn at Task launch
      actions.push({
        action_id: id,
        turn_id: '',
        action,
        status: 'ok',
        start_ts: new Date(st.mtimeMs).toISOString().replace(/\.\d{3}Z/, 'Z'),
        end_ts: new Date(st.mtimeMs).toISOString().replace(/\.\d{3}Z/, 'Z'),
        duration_ms: 0,
        tokens_est: estimateFile(file),
        token_source: 'transcript_estimate',
        tool_events: 0,
        tool_errors: 0,
        summary: truncate(text, 120),
        completed: true,
        subagent_session_id: id,
      });
    }
  }

  for (const t of turns) {
    t.action_ids = actions.filter((a) => a.turn_id === t.turn_id).map((a) => a.action_id);
    t.action_count = t.action_ids.length;
  }

  const tokensTurns = turns.reduce((s, t) => s + (t.tokens_est || 0), 0);
  const tokensActions = actions.reduce((s, a) => s + (a.tokens_est || 0), 0);
  const summary = {
    session_id: session,
    ide: 'cursor',
    updated_at: nowIso(),
    turn_count: turns.length,
    action_count: actions.length,
    tokens_est_turns: tokensTurns,
    tokens_est_actions: tokensActions,
    tokens_est_total: tokensTurns + tokensActions,
    token_source: 'transcript_estimate',
    tool_events: 0,
    tool_errors: 0,
    duration_ms: 0,
    current_turn_id: turns.length ? turns[turns.length - 1].turn_id : '',
    note: 'backfill: turns from parent transcript; actions from subagent files (turn_id empty). total = turns + actions.',
  };

  const state = {
    session_id: session,
    ide: 'cursor',
    created_at: nowIso(),
    updated_at: summary.updated_at,
    current_turn_id: summary.current_turn_id,
    turns: Object.fromEntries(turns.map((t) => [t.turn_id, t])),
    actions: Object.fromEntries(actions.map((a) => [a.action_id, a])),
    sticky: { action: '', subagent_id: '', turn_id: '', written_at: 0 },
  };

  fs.writeFileSync(path.join(dir, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
  fs.writeFileSync(
    path.join(dir, 'turns.jsonl'),
    turns.map((t) => JSON.stringify(t)).join('\n') + (turns.length ? '\n' : '')
  );
  fs.writeFileSync(
    path.join(dir, 'actions.jsonl'),
    actions.map((a) => JSON.stringify(a)).join('\n') + (actions.length ? '\n' : '')
  );
  fs.writeFileSync(path.join(dir, 'state.json'), JSON.stringify(state, null, 2) + '\n');
  console.log(
    `backfill ${session}: turns=${turns.length} actions=${actions.length} tokens_est=${summary.tokens_est_total}`
  );
}

const sessions = listParentSessions().filter((s) => !filter || s.session.includes(filter));
if (!sessions.length) {
  console.error('tool-audit-backfill: no parent transcripts found');
  process.exit(1);
}
for (const s of sessions) rebuild(s.session, s.file);
NODE
