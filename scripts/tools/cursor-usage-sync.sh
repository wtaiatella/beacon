#!/usr/bin/env bash
# Sync Cursor billing/usage API into docs/local/audit-cursor/<session>/.
#
# Auth: reads Workos session from Cursor's local state.vscdb on each run.
# Never writes the JWT to disk. Event payloads (no token) may be cached briefly.
#
# Usage:
#   scripts/tools/cursor-usage-sync.sh [--days 31] [session-id]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DAYS=31
SESSION=""

usage() {
  cat <<'EOF'
Usage: scripts/tools/cursor-usage-sync.sh [--days N] [session-id]

Fetches Cursor dashboard usage events (same source as the Cursor Usage extension)
and writes billing.json into matching docs/local/audit-cursor/<session>/ folders.
Also enriches summary.json / actions.jsonl / turns.jsonl with tokens_api + spend.

Auth token is read from Cursor state.vscdb each run and is never stored by us.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --days)
      DAYS="${2:-31}"
      shift 2
      ;;
    --days=*)
      DAYS="${1#--days=}"
      shift
      ;;
    *)
      SESSION="$1"
      shift
      ;;
  esac
done

export CURSOR_USAGE_ROOT="$ROOT"
export CURSOR_USAGE_DAYS="$DAYS"
export CURSOR_USAGE_SESSION="$SESSION"

node <<'NODE'
const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');
const { DatabaseSync } = require('node:sqlite');

const root = process.env.CURSOR_USAGE_ROOT;
const days = Math.max(1, parseInt(process.env.CURSOR_USAGE_DAYS || '31', 10) || 31);
const onlySession = process.env.CURSOR_USAGE_SESSION || '';

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z/, 'Z');
}

function stateDbPath() {
  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library/Application Support/Cursor/User/globalStorage/state.vscdb');
  }
  if (process.platform === 'win32') {
    return path.join(process.env.APPDATA || '', 'Cursor/User/globalStorage/state.vscdb');
  }
  return path.join(os.homedir(), '.config/Cursor/User/globalStorage/state.vscdb');
}

function readAuth() {
  const dbPath = stateDbPath();
  if (!fs.existsSync(dbPath)) {
    throw new Error('Cursor state.vscdb not found at ' + dbPath);
  }
  // Copy to temp — live DB may be locked / WAL-only for some keys.
  const tmp = path.join(os.tmpdir(), 'beacon-cursor-state-' + process.pid + '.vscdb');
  fs.copyFileSync(dbPath, tmp);
  try {
    const wal = dbPath + '-wal';
    const shm = dbPath + '-shm';
    if (fs.existsSync(wal)) fs.copyFileSync(wal, tmp + '-wal');
    if (fs.existsSync(shm)) fs.copyFileSync(shm, tmp + '-shm');
  } catch (_) {}

  let token = '';
  let email = '';
  try {
    const db = new DatabaseSync(tmp, { readOnly: true });
    const rows = db
      .prepare(
        "SELECT key, value FROM ItemTable WHERE key IN ('cursorAuth/accessToken','cursorAuth/cachedEmail')"
      )
      .all();
    for (const row of rows) {
      const v = Buffer.isBuffer(row.value) ? row.value.toString('utf8') : String(row.value || '');
      if (row.key === 'cursorAuth/accessToken') token = v;
      if (row.key === 'cursorAuth/cachedEmail') email = v;
    }
    db.close();
  } finally {
    try {
      fs.unlinkSync(tmp);
    } catch (_) {}
    try {
      fs.unlinkSync(tmp + '-wal');
    } catch (_) {}
    try {
      fs.unlinkSync(tmp + '-shm');
    } catch (_) {}
  }

  if (!token) throw new Error('cursorAuth/accessToken missing — is Cursor signed in?');

  const payloadB64 = token.split('.')[1];
  const padded = payloadB64 + '='.repeat((4 - (payloadB64.length % 4)) % 4);
  const claims = JSON.parse(Buffer.from(padded, 'base64url').toString('utf8'));
  const sub = String(claims.sub || '');
  const userId = sub.includes('|') ? sub.split('|')[1] : sub;
  return {
    userId,
    email,
    sessionToken: `${userId}%3A%3A${token}`,
    tokenLen: token.length,
  };
}

function httpJson(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const data = body == null ? null : Buffer.from(JSON.stringify(body));
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers: {
          ...headers,
          ...(data ? { 'Content-Length': String(data.length) } : {}),
        },
        timeout: 30000,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          let json = null;
          try {
            json = raw ? JSON.parse(raw) : null;
          } catch (_) {
            json = { raw: raw.slice(0, 2000) };
          }
          resolve({ status: res.statusCode || 0, json });
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('timeout ' + url));
    });
    if (data) req.write(data);
    req.end();
  });
}

function apiHeaders(sessionToken) {
  return {
    'Content-Type': 'application/json',
    Cookie: `WorkosCursorSessionToken=${sessionToken}`,
    Origin: 'https://cursor.com',
    Referer: 'https://cursor.com/dashboard',
    'User-Agent': 'beacon-cursor-usage-sync/1.0',
  };
}

function eventTokens(ev) {
  const tu = ev.tokenUsage || {};
  return (
    (Number(tu.inputTokens) || 0) +
    (Number(tu.outputTokens) || 0) +
    (Number(tu.cacheReadTokens) || 0) +
    (Number(tu.cacheWriteTokens) || 0)
  );
}

function normalizeEvent(ev) {
  const tu = ev.tokenUsage || {};
  return {
    timestamp: ev.timestamp,
    conversationId: ev.conversationId || '',
    model: ev.model || 'unknown',
    kind: ev.kind || '',
    maxMode: !!ev.maxMode,
    isHeadless: !!ev.isHeadless,
    isTokenBasedCall: ev.isTokenBasedCall,
    isChargeable: ev.isChargeable,
    requestsCosts: ev.requestsCosts ?? ev.numRequests ?? null,
    chargedCents: Number(ev.chargedCents) || 0,
    cursorTokenFee: ev.cursorTokenFee ?? null,
    usageBasedCosts: ev.usageBasedCosts ?? null,
    tokenUsage: {
      inputTokens: Number(tu.inputTokens) || 0,
      outputTokens: Number(tu.outputTokens) || 0,
      cacheWriteTokens: Number(tu.cacheWriteTokens) || 0,
      cacheReadTokens: Number(tu.cacheReadTokens) || 0,
      totalCents: tu.totalCents ?? null,
      enterpriseUsageDiscountPercent: tu.enterpriseUsageDiscountPercent ?? null,
    },
    tokens_total: eventTokens(ev),
  };
}

function parseTsMs(ts) {
  if (ts == null || ts === '') return null;
  if (typeof ts === 'number') return ts > 1e12 ? ts : ts * 1000;
  if (/^\d+$/.test(String(ts))) {
    const n = Number(ts);
    return n > 1e12 ? n : n * 1000;
  }
  const d = Date.parse(String(ts));
  return Number.isFinite(d) ? d : null;
}

function aggregateEvents(list) {
  const models = {};
  const kinds = {};
  let tokens = 0;
  let spend = 0;
  let input = 0;
  let output = 0;
  let cacheRead = 0;
  let cacheWrite = 0;
  let requests = 0;
  for (const ev of list) {
    const tu = ev.tokenUsage || {};
    tokens += ev.tokens_total || eventTokens(ev);
    spend += Number(ev.chargedCents) || 0;
    input += Number(tu.inputTokens) || 0;
    output += Number(tu.outputTokens) || 0;
    cacheRead += Number(tu.cacheReadTokens) || 0;
    cacheWrite += Number(tu.cacheWriteTokens) || 0;
    requests += Number(ev.requestsCosts) || 0;
    const m = ev.model || 'unknown';
    models[m] = (models[m] || 0) + 1;
    const k = ev.kind || 'unknown';
    kinds[k] = (kinds[k] || 0) + 1;
  }
  return {
    event_count: list.length,
    tokens_api: tokens,
    spend_cents: Math.round(spend * 1000) / 1000,
    spend_dollars: Math.round((spend / 100) * 10000) / 10000,
    input_tokens: input,
    output_tokens: output,
    cache_read_tokens: cacheRead,
    cache_write_tokens: cacheWrite,
    requests_costs: requests,
    models,
    kinds,
  };
}

async function fetchAllEvents(auth, teamId) {
  const headers = apiHeaders(auth.sessionToken);
  const end = Date.now();
  const start = end - days * 86400 * 1000;
  const events = [];
  let total = null;
  for (let page = 1; page <= 20; page++) {
    const res = await httpJson(
      'POST',
      'https://cursor.com/api/dashboard/get-filtered-usage-events',
      headers,
      {
        teamId: teamId || 0,
        startDate: String(start),
        endDate: String(end),
        page,
        pageSize: 500,
      }
    );
    if (res.status !== 200 || !res.json || typeof res.json !== 'object') {
      throw new Error(`get-filtered-usage-events failed: HTTP ${res.status}`);
    }
    const batch = Array.isArray(res.json.usageEventsDisplay) ? res.json.usageEventsDisplay : [];
    if (total == null) total = res.json.totalUsageEventsCount;
    for (const ev of batch) events.push(normalizeEvent(ev));
    if (batch.length < 500) break;
  }
  return { events, total, startMs: start, endMs: end };
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return null;
  }
}

function readJsonl(file) {
  if (!fs.existsSync(file)) return [];
  return fs
    .readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean)
    .map((l) => {
      try {
        return JSON.parse(l);
      } catch (_) {
        return null;
      }
    })
    .filter(Boolean);
}

function writeJson(file, obj) {
  fs.writeFileSync(file, JSON.stringify(obj, null, 2) + '\n');
}

function writeJsonl(file, rows) {
  fs.writeFileSync(file, rows.map((r) => JSON.stringify(r)).join('\n') + (rows.length ? '\n' : ''));
}

function listChatDirs() {
  const base = path.join(root, 'docs/local/audit-cursor');
  if (!fs.existsSync(base)) return [];
  return fs
    .readdirSync(base, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => path.join(base, d.name))
    .filter((dir) => !onlySession || path.basename(dir).includes(onlySession));
}

function childIdsForSession(sessionId) {
  const hash = String(root)
    .replace(/^\/+/, '')
    .replace(/[/.]+/g, '-')
    .replace(/^-+|-+$/g, '');
  const subDir = path.join(
    os.homedir(),
    '.cursor/projects',
    hash,
    'agent-transcripts',
    sessionId,
    'subagents'
  );
  if (!fs.existsSync(subDir)) return new Set();
  return new Set(
    fs
      .readdirSync(subDir)
      .filter((n) => n.endsWith('.jsonl'))
      .map((n) => n.replace(/\.jsonl$/, ''))
  );
}

function parentTranscriptPath(sessionId) {
  const hash = String(root)
    .replace(/^\/+/, '')
    .replace(/[/.]+/g, '-')
    .replace(/^-+|-+$/g, '');
  const p = path.join(
    os.homedir(),
    '.cursor/projects',
    hash,
    'agent-transcripts',
    sessionId,
    sessionId + '.jsonl'
  );
  return fs.existsSync(p) ? p : '';
}

function parseEmbeddedTimestamp(text) {
  const s = String(text || '');
  const m = s.match(/<timestamp>\s*([^<]+?)\s*<\/timestamp>/i);
  if (!m) return '';
  const raw = m[1].trim();
  const cleaned = raw.replace(/\s*\(([^)]+)\)\s*$/, (_, tz) => {
    const t = String(tz).trim().toUpperCase();
    if (t === 'UTC' || t === 'GMT') return ' GMT+0000';
    const mm = t.match(/^UTC([+-])(\d{1,2})(?::?(\d{2}))?$/);
    if (mm) {
      const sign = mm[1] === '-' ? '-' : '+';
      const hh = String(mm[2]).padStart(2, '0');
      const min = String(mm[3] || '0').padStart(2, '0');
      return ` GMT${sign}${hh}${min}`;
    }
    return '';
  });
  const ms = Date.parse(cleaned);
  if (!Number.isFinite(ms)) {
    const ms2 = Date.parse(raw);
    return Number.isFinite(ms2) ? new Date(ms2).toISOString().replace(/\.\d{3}Z/, 'Z') : '';
  }
  return new Date(ms).toISOString().replace(/\.\d{3}Z/, 'Z');
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

/** Refresh turn start/end from parent transcript timestamps (embedded <timestamp>). */
function refreshTurnTimestamps(sessionId, turns) {
  const file = parentTranscriptPath(sessionId);
  if (!file || !turns.length) return turns;
  const records = fs
    .readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean)
    .map((l) => {
      try {
        return JSON.parse(l);
      } catch (_) {
        return null;
      }
    })
    .filter(Boolean);
  const userTs = [];
  for (const rec of records) {
    if (String(rec.role || '').toLowerCase() !== 'user') continue;
    const raw = extractUserText(rec);
    const ts = parseEmbeddedTimestamp(raw);
    if (ts) userTs.push(ts);
  }
  if (!userTs.length) return turns;
  const sorted = [...turns].sort((a, b) => (a.index || 0) - (b.index || 0));
  for (let i = 0; i < sorted.length; i++) {
    if (userTs[i]) {
      sorted[i].start_ts = userTs[i];
      sorted[i].end_ts = userTs[i + 1] || nowIso();
      sorted[i].duration_ms = Math.max(
        0,
        (Date.parse(sorted[i].end_ts) || 0) - (Date.parse(sorted[i].start_ts) || 0)
      );
    }
  }
  return sorted;
}

function findTurnForMs(turns, ms) {
  if (ms == null) return null;
  const sorted = [...turns].sort((a, b) => (a.index || 0) - (b.index || 0));
  for (let i = 0; i < sorted.length; i++) {
    const start = parseTsMs(sorted[i].start_ts);
    const end =
      i + 1 < sorted.length ? parseTsMs(sorted[i + 1].start_ts) : Date.now() + 86400000;
    if (start != null && ms >= start && ms < (end == null ? Infinity : end)) return sorted[i];
  }
  return null;
}

function enrichChat(dir, byConversation) {
  const sessionId = path.basename(dir);
  const summaryPath = path.join(dir, 'summary.json');
  const actionsPath = path.join(dir, 'actions.jsonl');
  const turnsPath = path.join(dir, 'turns.jsonl');
  const statePath = path.join(dir, 'state.json');

  const summary = readJson(summaryPath) || { session_id: sessionId };
  let actions = readJsonl(actionsPath);
  let turns = refreshTurnTimestamps(sessionId, readJsonl(turnsPath));
  const state = readJson(statePath) || {};

  const children = childIdsForSession(sessionId);
  const parentEvents = byConversation.get(sessionId) || [];
  const childEvents = [];
  for (const id of children) {
    for (const ev of byConversation.get(id) || []) childEvents.push(ev);
  }
  // Also include action_ids even if transcript folder missing
  for (const a of actions) {
    const id = a.action_id || a.subagent_session_id;
    if (!id || children.has(id) || id === sessionId) continue;
    for (const ev of byConversation.get(id) || []) childEvents.push(ev);
  }

  const allEvents = [...parentEvents, ...childEvents];
  const chatAgg = aggregateEvents(allEvents);
  const parentAgg = aggregateEvents(parentEvents);
  const actionsAgg = aggregateEvents(childEvents);

  // Enrich actions + link to turn by first event timestamp when turn_id empty
  const enrichedActions = actions.map((a) => {
    const id = a.action_id || a.subagent_session_id;
    const evs = byConversation.get(id) || [];
    const agg = aggregateEvents(evs);
    let turnId = a.turn_id || '';
    if (!turnId && evs.length) {
      const firstMs = Math.min(
        ...evs.map((e) => parseTsMs(e.timestamp)).filter((n) => n != null)
      );
      const turn = findTurnForMs(turns, firstMs);
      if (turn) turnId = turn.turn_id;
    }
    return {
      ...a,
      turn_id: turnId,
      tokens_api: agg.tokens_api,
      spend_cents: agg.spend_cents,
      spend_dollars: agg.spend_dollars,
      billing_events: agg.event_count,
      billing_models: agg.models,
      billing_kinds: agg.kinds,
      input_tokens: agg.input_tokens,
      output_tokens: agg.output_tokens,
      cache_read_tokens: agg.cache_read_tokens,
      cache_write_tokens: agg.cache_write_tokens,
      billing_source: 'cursor_api',
    };
  });

  // Enrich turns: parent events in window + linked actions
  const enrichedTurns = turns.map((t, idx) => {
    const start = parseTsMs(t.start_ts);
    const next = turns[idx + 1];
    const end = next ? parseTsMs(next.start_ts) : Date.now() + 60_000;
    const inWindow = parentEvents.filter((ev) => {
      const ts = parseTsMs(ev.timestamp);
      if (ts == null || start == null) return false;
      return ts >= start && ts < (end == null ? Infinity : end);
    });
    const linkedActionEvents = [];
    for (const a of enrichedActions) {
      if (a.turn_id === t.turn_id) {
        const id = a.action_id || a.subagent_session_id;
        for (const ev of byConversation.get(id) || []) linkedActionEvents.push(ev);
      }
    }
    const agg = aggregateEvents([...inWindow, ...linkedActionEvents]);
    return {
      ...t,
      end_ts: next ? next.start_ts : t.end_ts,
      duration_ms:
        start != null && end != null ? Math.max(0, end - start) : t.duration_ms || 0,
      action_ids: enrichedActions.filter((a) => a.turn_id === t.turn_id).map((a) => a.action_id),
      action_count: enrichedActions.filter((a) => a.turn_id === t.turn_id).length,
      tokens_api: agg.tokens_api,
      spend_cents: agg.spend_cents,
      spend_dollars: agg.spend_dollars,
      billing_events: agg.event_count,
      billing_models: agg.models,
      input_tokens: agg.input_tokens,
      output_tokens: agg.output_tokens,
      cache_read_tokens: agg.cache_read_tokens,
      cache_write_tokens: agg.cache_write_tokens,
      billing_source: 'cursor_api',
    };
  });

  const billing = {
    session_id: sessionId,
    synced_at: nowIso(),
    source: 'cursor.com/api/dashboard/get-filtered-usage-events',
    auth: { mode: 'state.vscdb_read_once_per_sync', token_stored: false },
    window_days: days,
    parent: parentAgg,
    actions: actionsAgg,
    total: chatAgg,
    events: allEvents,
  };

  const newSummary = {
    ...summary,
    updated_at: nowIso(),
    tokens_api_total: chatAgg.tokens_api,
    tokens_api_parent: parentAgg.tokens_api,
    tokens_api_actions: actionsAgg.tokens_api,
    spend_cents_total: chatAgg.spend_cents,
    spend_dollars_total: chatAgg.spend_dollars,
    billing_events: chatAgg.event_count,
    billing_models: chatAgg.models,
    billing_kinds: chatAgg.kinds,
    billing_synced_at: billing.synced_at,
    billing_source: 'cursor_api',
    note:
      'tokens_api_* / spend_* from Cursor Usage API (conversationId). tokens_est_* remain transcript chars/4 fallback.',
  };

  writeJson(path.join(dir, 'billing.json'), billing);
  writeJson(summaryPath, newSummary);
  writeJsonl(actionsPath, enrichedActions);
  writeJsonl(turnsPath, enrichedTurns);

  if (state && typeof state === 'object') {
    state.updated_at = nowIso();
    if (state.actions && typeof state.actions === 'object') {
      for (const a of enrichedActions) {
        if (state.actions[a.action_id]) {
          state.actions[a.action_id] = { ...state.actions[a.action_id], ...a };
        }
      }
    }
    if (state.turns && typeof state.turns === 'object') {
      for (const t of enrichedTurns) {
        if (state.turns[t.turn_id]) {
          state.turns[t.turn_id] = { ...state.turns[t.turn_id], ...t };
        }
      }
    }
    writeJson(statePath, state);
  }

  return {
    sessionId,
    events: chatAgg.event_count,
    tokens: chatAgg.tokens_api,
    spend: chatAgg.spend_dollars,
    actions: enrichedActions.length,
  };
}

(async () => {
  const auth = readAuth();
  // sessionToken stays in-memory only for this process
  const headers = apiHeaders(auth.sessionToken);
  const stripe = await httpJson('GET', 'https://cursor.com/api/auth/stripe', headers);
  const teamId =
    stripe.status === 200 && stripe.json && stripe.json.teamId ? stripe.json.teamId : 0;

  const { events, total, startMs, endMs } = await fetchAllEvents(auth, teamId);

  // Optional short cache of events (never the token)
  const cacheDir = path.join(root, 'docs/local/cursor-usage-cache');
  fs.mkdirSync(cacheDir, { recursive: true });
  writeJson(path.join(cacheDir, 'last-fetch.json'), {
    fetched_at: nowIso(),
    days,
    teamId,
    userId: auth.userId,
    email: auth.email,
    token_stored: false,
    event_count: events.length,
    totalUsageEventsCount: total,
    window: { startMs, endMs },
  });
  writeJsonl(path.join(cacheDir, 'events.jsonl'), events);

  const byConversation = new Map();
  for (const ev of events) {
    const id = ev.conversationId || '';
    if (!id) continue;
    if (!byConversation.has(id)) byConversation.set(id, []);
    byConversation.get(id).push(ev);
  }

  const dirs = listChatDirs();
  if (!dirs.length) {
    console.log(
      `fetched ${events.length} events (total=${total}); no audit-cursor chats to enrich` +
        (onlySession ? ` (filter=${onlySession})` : '')
    );
    process.exit(0);
  }

  const results = [];
  for (const dir of dirs) {
    results.push(enrichChat(dir, byConversation));
  }

  console.log(
    `auth: state.vscdb → memory only (token_len=${auth.tokenLen}, stored=false) user=${auth.email || auth.userId}`
  );
  console.log(`fetched: ${events.length}/${total ?? '?'} events over ${days}d teamId=${teamId}`);
  for (const r of results) {
    console.log(
      `chat ${r.sessionId}: events=${r.events} tokens_api=${r.tokens} spend=$${r.spend} actions=${r.actions}`
    );
  }
})().catch((err) => {
  console.error('cursor-usage-sync failed:', err && err.message ? err.message : err);
  process.exit(1);
});
NODE
