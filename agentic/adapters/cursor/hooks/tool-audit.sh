#!/usr/bin/env bash
# tool-audit (Cursor) — chat-centric usage audit.
# Source: agentic/adapters/cursor/hooks/tool-audit.sh
# Installed to: .cursor/hooks/tool-audit.sh via setup-agentic.sh cursor
#
# Layout (one folder per Cursor chat / conversation):
#   docs/local/audit-cursor/<session_id>/
#     summary.json   — chat totals
#     turns.jsonl    — one record per user question
#     actions.jsonl  — Task/subagent work nested under a turn
#     state.json     — mutable working state
#
# Token numbers are estimates (transcript chars/4). They are closer to reality at
# chat/turn level (parent transcript) than at Task level. Subagent estimates are
# secondary and usually undercount (tool results are absent from jsonl).
#
# Events: beforeSubmitPrompt, postToolUse, postToolUseFailure, subagentStop, stop
# Fail-open; observers emit no stdout.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
RUNTIME_HINT="cursor"

export HOOK_DIR="$DIR"
export HOOK_ROOT="$ROOT"
export HOOK_RUNTIME_HINT="$RUNTIME_HINT"
export HOOK_INPUT="$(cat || true)"

node <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const proto = require(process.env.HOOK_DIR + '/lib/hook-protocol');

const root = process.env.HOOK_ROOT;
const runtimeHint = process.env.HOOK_RUNTIME_HINT || '';
const input = proto.readInput();

function truncate(s, max) {
  s = String(s || '').replace(/\s+/g, ' ').trim();
  return s.length > max ? s.slice(0, max - 3) + '...' : s;
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

function eventOf(j) {
  return (
    j.hook_event_name ||
    j.hookEventName ||
    j.event ||
    (j.failure_type || j.error_message ? 'postToolUseFailure' : 'postToolUse')
  );
}

function isFailureEvent(event) {
  return /postToolUseFailure|PostToolUseFailure/i.test(String(event || ''));
}

function isStopEvent(event) {
  return /^(subagentStop|stop|TaskStop|taskStop|SubagentStop|Stop)$/i.test(String(event || ''));
}

function isPromptEvent(event) {
  return /^(beforeSubmitPrompt|UserPromptSubmit)$/i.test(String(event || ''));
}

function terminalStatusOf(j) {
  const raw = String(j.status || j.subagent_status || j.agent_status || '').toLowerCase();
  if (raw === 'completed' || raw === 'ok' || raw === 'success') return 'ok';
  if (raw === 'error' || raw === 'failed' || raw === 'failure') return 'error';
  if (raw === 'aborted' || raw === 'cancelled' || raw === 'canceled') return 'aborted';
  return 'ok';
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

function cursorProjectHash(workspaceRoot) {
  return String(workspaceRoot || '')
    .replace(/^\/+/, '')
    .replace(/[/.]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function agentTranscriptRoots() {
  const home = process.env.HOME || '';
  if (!home) return [];
  return [path.join(home, '.cursor', 'projects', cursorProjectHash(root), 'agent-transcripts')];
}

function findTranscriptBySession(session) {
  if (!session || session === 'unknown') return '';
  for (const base of agentTranscriptRoots()) {
    try {
      const stack = [base];
      let seen = 0;
      while (stack.length && seen < 2000) {
        const dir = stack.pop();
        seen += 1;
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const p = path.join(dir, entry.name);
          if (entry.isDirectory()) stack.push(p);
          else if (entry.isFile() && entry.name === session + '.jsonl') return p;
        }
      }
    } catch (_) {}
  }
  return '';
}

function parentSessionFromTranscript(transcriptPath) {
  const m = String(transcriptPath || '').match(
    /agent-transcripts[/\\]([^/\\]+)[/\\]subagents[/\\]/i
  );
  return m ? m[1] : '';
}

function isSubagentTranscriptPath(transcriptPath) {
  return /[/\\]subagents[/\\]/i.test(String(transcriptPath || ''));
}

function resolveTranscriptPath(j, session) {
  return (
    j.agent_transcript_path ||
    j.agentTranscriptPath ||
    j.transcript_path ||
    j.transcriptPath ||
    findTranscriptBySession(session) ||
    ''
  );
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

function readTranscriptRecords(transcriptPath) {
  if (!transcriptPath || !fs.existsSync(transcriptPath)) return [];
  try {
    const st = fs.statSync(transcriptPath);
    const max = 12 * 1024 * 1024;
    const start = Math.max(0, st.size - max);
    const fd = fs.openSync(transcriptPath, 'r');
    const buf = Buffer.alloc(st.size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    fs.closeSync(fd);
    const out = [];
    for (const line of buf.toString('utf8').split(/\r?\n/)) {
      if (!line) continue;
      const parsed = parseMaybeJson(line);
      if (parsed) out.push(parsed);
    }
    return out;
  } catch (_) {
    return [];
  }
}

function estimateTranscriptFile(transcriptPath) {
  const records = readTranscriptRecords(transcriptPath);
  if (!records.length) return { chars: 0, tokens: 0, source: 'none' };
  let chars = 0;
  for (const rec of records) chars += collectTextChars(rec);
  return {
    chars,
    tokens: estimateTokensFromChars(chars),
    source: 'transcript_estimate',
  };
}

function extractUserText(rec) {
  const msg = rec.message || rec;
  const content = msg.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part === 'object') {
          if (typeof part.text === 'string') return part.text;
          if (typeof part.content === 'string') return part.content;
        }
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

/** Parse Cursor-injected <timestamp>...</timestamp> into ISO UTC. */
function parseEmbeddedTimestamp(text) {
  const s = String(text || '');
  const m = s.match(/<timestamp>\s*([^<]+?)\s*<\/timestamp>/i);
  if (!m) return '';
  const raw = m[1].trim();
  // e.g. "Monday, Aug 10, 2026, 5:11 PM (UTC-3)"
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
    if (!Number.isFinite(ms2)) return '';
    return new Date(ms2).toISOString().replace(/\.\d{3}Z/, 'Z');
  }
  return new Date(ms).toISOString().replace(/\.\d{3}Z/, 'Z');
}

function isoFromUnknown(ts, fallback) {
  if (typeof ts === 'string' && ts.includes('T') && !Number.isNaN(Date.parse(ts))) {
    return new Date(Date.parse(ts)).toISOString().replace(/\.\d{3}Z/, 'Z');
  }
  if (typeof ts === 'number' && Number.isFinite(ts)) {
    const ms = ts > 1e12 ? ts : ts * 1000;
    return new Date(ms).toISOString().replace(/\.\d{3}Z/, 'Z');
  }
  return fallback || nowIso();
}

function promptOf(j) {
  return (
    j.prompt ||
    j.user_prompt ||
    j.userPrompt ||
    j.message ||
    j.text ||
    (j.content && typeof j.content === 'string' ? j.content : '') ||
    ''
  );
}

function turnIdFromPrompt(prompt, index) {
  const h = crypto
    .createHash('sha1')
    .update(String(index) + '\n' + String(prompt || '').slice(0, 500))
    .digest('hex')
    .slice(0, 12);
  return 't' + index + '-' + h;
}

/** Split parent transcript into user turns with char/token estimates. */
function turnsFromParentTranscript(transcriptPath) {
  const records = readTranscriptRecords(transcriptPath);
  const turns = [];
  let current = null;
  let index = 0;

  function closeCurrent() {
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
    const role = String(rec.role || rec.message?.role || '').toLowerCase();
    const chars = collectTextChars(rec);
    const rawText = role === 'user' ? extractUserText(rec) : '';
    const embedded = role === 'user' ? parseEmbeddedTimestamp(rawText) : '';
    const ts = embedded || isoFromUnknown(rec.timestamp || rec.message?.timestamp, nowIso());

    if (role === 'user') {
      if (current) {
        current.end_ts = ts;
      }
      closeCurrent();
      index += 1;
      const prompt = stripUserQueryWrapper(rawText);
      current = {
        turn_id: turnIdFromPrompt(prompt, index),
        index,
        start_ts: ts,
        end_ts: ts,
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
      continue;
    }

    if (current) {
      current._chars += chars;
      current.end_ts = isoFromUnknown(rec.timestamp || rec.message?.timestamp, current.end_ts || nowIso());
    }
  }
  closeCurrent();
  if (turns.length) turns[turns.length - 1].status = 'open';
  return turns;
}

function explicitActionOf(j) {
  const ti = proto.toolInput(j);
  const subagent =
    ti.subagent_type ||
    ti.subagentType ||
    j.subagent_type ||
    j.subagentType ||
    j.agent ||
    '';
  if (subagent) {
    return {
      action: String(subagent),
      strength: 'strong',
      summary: truncate(ti.description || j.description || subagent, 160),
    };
  }
  return { action: '', strength: 'none', summary: '' };
}

function chatDir(base, session) {
  return path.join(base, safeSegment(session));
}

function emptyState(session) {
  return {
    session_id: session,
    ide: 'cursor',
    created_at: nowIso(),
    updated_at: nowIso(),
    current_turn_id: '',
    turns: {},
    actions: {},
    sticky: { action: '', subagent_id: '', turn_id: '', written_at: 0 },
  };
}

function readState(file, session) {
  try {
    const s = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (s && typeof s === 'object') {
      s.turns = s.turns || {};
      s.actions = s.actions || {};
      s.sticky = s.sticky || { action: '', subagent_id: '', turn_id: '', written_at: 0 };
      return s;
    }
  } catch (_) {}
  return emptyState(session);
}

function writeJson(file, obj) {
  fs.writeFileSync(file, JSON.stringify(obj, null, 2) + '\n');
}

function writeJsonl(file, rows) {
  const body = rows.map((r) => JSON.stringify(r)).join('\n');
  fs.writeFileSync(file, body + (rows.length ? '\n' : ''));
}

function rebuildArtifacts(dir, state) {
  const turns = Object.values(state.turns || {}).sort(
    (a, b) => (a.index || 0) - (b.index || 0) || String(a.start_ts).localeCompare(String(b.start_ts))
  );
  const actions = Object.values(state.actions || {}).sort((a, b) =>
    String(a.start_ts).localeCompare(String(b.start_ts))
  );

  for (const t of turns) {
    t.action_ids = actions.filter((a) => a.turn_id === t.turn_id).map((a) => a.action_id);
    t.action_count = t.action_ids.length;
  }

  const chatTokens = turns.reduce((sum, t) => sum + (Number(t.tokens_est) || 0), 0);
  const actionTokens = actions.reduce((sum, a) => sum + (Number(a.tokens_est) || 0), 0);
  // Parent transcript omits most subagent tool I/O; combining is closer to real usage
  // (some overlap possible on final Task replies echoed to the parent).
  const combinedTokens = chatTokens + actionTokens;
  const chatTools = turns.reduce((sum, t) => sum + (Number(t.tool_events) || 0), 0);
  const chatErrors = turns.reduce((sum, t) => sum + (Number(t.tool_errors) || 0), 0);
  const openTurn = turns.filter((t) => t.status === 'open').slice(-1)[0];
  const first = turns[0];
  const last = turns[turns.length - 1];

  const prevSummary = readJson(path.join(dir, 'summary.json')) || {};
  const billingKeep = {};
  for (const k of Object.keys(prevSummary)) {
    if (
      k.startsWith('tokens_api') ||
      k.startsWith('spend_') ||
      k.startsWith('billing_') ||
      k === 'input_tokens' ||
      k === 'output_tokens'
    ) {
      billingKeep[k] = prevSummary[k];
    }
  }

  const summary = {
    session_id: state.session_id,
    ide: 'cursor',
    updated_at: nowIso(),
    turn_count: turns.length,
    action_count: actions.length,
    tokens_est_turns: chatTokens,
    tokens_est_actions: actionTokens,
    tokens_est_total: combinedTokens,
    token_source: 'transcript_estimate',
    tool_events: chatTools,
    tool_errors: chatErrors,
    duration_ms:
      first && last
        ? Math.max(0, (Date.parse(last.end_ts) || 0) - (Date.parse(first.start_ts) || 0))
        : 0,
    current_turn_id: openTurn ? openTurn.turn_id : state.current_turn_id || '',
    ...billingKeep,
    note:
      billingKeep.billing_source === 'cursor_api'
        ? 'tokens_api_* / spend_* from Cursor Usage API. tokens_est_* = transcript chars/4 fallback. Run scripts/tools/cursor-usage-sync.sh to refresh billing.'
        : 'tokens_est_* = chars/4 fallback. Prefer scripts/tools/cursor-usage-sync.sh for real tokens_api / spend.',
  };

  writeJson(path.join(dir, 'summary.json'), summary);
  writeJsonl(
    path.join(dir, 'turns.jsonl'),
    turns.map(({ _chars, ...rest }) => rest)
  );
  writeJsonl(path.join(dir, 'actions.jsonl'), actions);
  state.updated_at = summary.updated_at;
  writeJson(path.join(dir, 'state.json'), state);
  return summary;
}

function ensureTurn(state, turnLike) {
  const id = turnLike.turn_id;
  if (!id) return null;
  const prev = state.turns[id] || {};
  const billingKeep = {};
  for (const k of Object.keys(prev)) {
    if (
      k.startsWith('tokens_api') ||
      k.startsWith('spend_') ||
      k.startsWith('billing_') ||
      k === 'input_tokens' ||
      k === 'output_tokens' ||
      k === 'cache_read_tokens' ||
      k === 'cache_write_tokens'
    ) {
      billingKeep[k] = prev[k];
    }
  }
  state.turns[id] = {
    turn_id: id,
    index: turnLike.index || prev.index || Object.keys(state.turns).length + 1,
    start_ts: turnLike.start_ts || prev.start_ts || nowIso(),
    end_ts: turnLike.end_ts || prev.end_ts || nowIso(),
    status: turnLike.status || prev.status || 'open',
    prompt_preview: turnLike.prompt_preview || prev.prompt_preview || '',
    tokens_est: turnLike.tokens_est != null ? turnLike.tokens_est : prev.tokens_est || 0,
    token_source: turnLike.token_source || prev.token_source || 'transcript_estimate',
    duration_ms: turnLike.duration_ms != null ? turnLike.duration_ms : prev.duration_ms || 0,
    tool_events: Math.max(prev.tool_events || 0, turnLike.tool_events || 0),
    tool_errors: Math.max(prev.tool_errors || 0, turnLike.tool_errors || 0),
    action_ids: prev.action_ids || [],
    ...billingKeep,
  };
  return state.turns[id];
}

function mergeTranscriptTurns(state, transcriptTurns) {
  for (const t of transcriptTurns) {
    const prev = state.turns[t.turn_id];
    ensureTurn(state, {
      ...t,
      // Preserve live tool counters if we already tracked them.
      tool_events: Math.max(t.tool_events || 0, (prev && prev.tool_events) || 0),
      tool_errors: Math.max(t.tool_errors || 0, (prev && prev.tool_errors) || 0),
    });
  }
  if (transcriptTurns.length) {
    const last = transcriptTurns[transcriptTurns.length - 1];
    state.current_turn_id = last.turn_id;
  }
}

function currentTurn(state) {
  if (state.current_turn_id && state.turns[state.current_turn_id]) {
    return state.turns[state.current_turn_id];
  }
  const open = Object.values(state.turns).filter((t) => t.status === 'open');
  if (open.length) return open.sort((a, b) => (a.index || 0) - (b.index || 0)).slice(-1)[0];
  const all = Object.values(state.turns).sort((a, b) => (a.index || 0) - (b.index || 0));
  return all.slice(-1)[0] || null;
}

function bumpTurnTools(state, failure) {
  const turn = currentTurn(state);
  if (!turn) return;
  turn.tool_events = (turn.tool_events || 0) + 1;
  if (failure) turn.tool_errors = (turn.tool_errors || 0) + 1;
  turn.end_ts = nowIso();
  turn.status = 'open';
}

function upsertAction(state, fields) {
  const id = fields.action_id;
  if (!id) return null;
  const prev = state.actions[id] || {};
  if (prev.completed && !fields.completed) return prev;

  const turn = currentTurn(state);
  const turnId = fields.turn_id || prev.turn_id || (turn && turn.turn_id) || '';
  const startTs = prev.start_ts || fields.start_ts || nowIso();
  const endTs = fields.end_ts || nowIso();
  let durationMs = Math.max(0, (Date.parse(endTs) || 0) - (Date.parse(startTs) || 0));
  if (fields.duration_ms != null && Number.isFinite(Number(fields.duration_ms))) {
    durationMs = Math.round(Number(fields.duration_ms));
  }

  const tokensEst =
    fields.tokens_est != null
      ? fields.tokens_est
      : fields.recompute_tokens
        ? estimateTranscriptFile(fields.transcript_path || '').tokens
        : prev.tokens_est || 0;

  const action = {
    action_id: id,
    turn_id: turnId,
    action: fields.action || prev.action || 'unknown',
    status: fields.completed ? fields.status || 'ok' : prev.completed ? prev.status : 'running',
    start_ts: startTs,
    end_ts: endTs,
    duration_ms: durationMs,
    tokens_est: tokensEst,
    token_source: fields.token_source || prev.token_source || 'transcript_estimate',
    tool_events: (prev.tool_events || 0) + (fields.count_tool ? 1 : 0),
    tool_errors: (prev.tool_errors || 0) + (fields.count_error ? 1 : 0),
    summary: fields.summary || prev.summary || '',
    completed: Boolean(prev.completed || fields.completed),
    subagent_session_id: fields.subagent_session_id || prev.subagent_session_id || id,
  };
  state.actions[id] = action;
  return action;
}

try {
  const ts = nowIso();
  const ide = proto.ideOf(input, runtimeHint);
  if (ide !== 'cursor') process.exit(0);

  const event = eventOf(input);
  const tool = proto.toolNameOf(input);
  const failureEvent = isFailureEvent(event);
  const stopEvent = isStopEvent(event);
  const promptEvent = isPromptEvent(event);

  const hookSession = proto.sessionIdOf(input) || 'unknown';
  const transcriptPath = resolveTranscriptPath(input, hookSession);
  const parentFromPath = parentSessionFromTranscript(transcriptPath);
  const chatSession = parentFromPath || hookSession;
  if (!chatSession || chatSession === 'unknown') process.exit(0);

  const subagentSession = isSubagentTranscriptPath(transcriptPath)
    ? path.basename(transcriptPath, '.jsonl')
    : parentFromPath && hookSession !== parentFromPath
      ? hookSession
      : '';

  const base = path.join(root, 'docs', 'local', 'audit-cursor');
  const dir = chatDir(base, chatSession);
  fs.mkdirSync(dir, { recursive: true });
  const stateFile = path.join(dir, 'state.json');
  const state = readState(stateFile, chatSession);

  const parentTranscript =
    findTranscriptBySession(chatSession) ||
    (!isSubagentTranscriptPath(transcriptPath) ? transcriptPath : '') ||
    '';

  // Always refresh turn estimates from the parent chat transcript when available.
  if (parentTranscript) {
    mergeTranscriptTurns(state, turnsFromParentTranscript(parentTranscript));
  }

  if (promptEvent) {
    const prompt = String(promptOf(input) || '').trim();
    // Close previous open turns.
    for (const t of Object.values(state.turns)) {
      if (t.status === 'open') t.status = 'closed';
    }
    const index = Object.keys(state.turns).length + 1;
    const turn_id = turnIdFromPrompt(prompt, index);
    // If transcript sync already created an equivalent last turn, reuse it.
    const last = Object.values(state.turns)
      .sort((a, b) => (a.index || 0) - (b.index || 0))
      .slice(-1)[0];
    if (last && last.prompt_preview && prompt && last.prompt_preview === truncate(prompt, 160)) {
      last.status = 'open';
      last.end_ts = ts;
      state.current_turn_id = last.turn_id;
    } else if (!parentTranscript || !Object.keys(state.turns).length) {
      ensureTurn(state, {
        turn_id,
        index,
        start_ts: ts,
        end_ts: ts,
        status: 'open',
        prompt_preview: truncate(prompt, 160),
        tokens_est: estimateTokensFromChars(prompt.length),
        token_source: 'prompt_estimate',
      });
      state.current_turn_id = turn_id;
    } else {
      const open = Object.values(state.turns)
        .filter((t) => t.status === 'open')
        .sort((a, b) => (a.index || 0) - (b.index || 0))
        .slice(-1)[0];
      if (open) {
        open.prompt_preview = truncate(prompt || open.prompt_preview, 160);
        open.end_ts = ts;
        state.current_turn_id = open.turn_id;
      }
    }
    state.sticky = { action: '', subagent_id: '', turn_id: state.current_turn_id, written_at: Date.now() };
    rebuildArtifacts(dir, state);
    process.exit(0);
  }

  const explicit = explicitActionOf(input);

  // Parent-side Task launch: remember intended action for the next subagent events.
  if (
    explicit.strength === 'strong' &&
    (tool === 'Task' || tool === 'Subagent') &&
    !subagentSession
  ) {
    state.sticky = {
      action: explicit.action,
      subagent_id: '',
      turn_id: (currentTurn(state) && currentTurn(state).turn_id) || '',
      written_at: Date.now(),
      summary: explicit.summary,
    };
  }

  // Prefer real subagent id as action key — never the parent chat id.
  if (subagentSession) {
    const actionName =
      (stopEvent && (input.subagent_type || input.subagentType)) ||
      explicit.action ||
      (state.sticky.subagent_id === subagentSession ? state.sticky.action : '') ||
      state.sticky.action ||
      'subagent';

    if (state.sticky.action && !state.sticky.subagent_id) {
      state.sticky.subagent_id = subagentSession;
      state.sticky.action = actionName;
      state.sticky.written_at = Date.now();
    }

    const completed = stopEvent && /subagentStop|TaskStop|taskStop|SubagentStop/i.test(event);
    const subPath =
      isSubagentTranscriptPath(transcriptPath) && transcriptPath
        ? transcriptPath
        : findTranscriptBySession(subagentSession);

    let durationMs = proto.durationOf(input);
    if (stopEvent && (input.duration_ms != null || input.durationMs != null)) {
      durationMs = String(Math.round(Number(input.duration_ms ?? input.durationMs)));
    }

    upsertAction(state, {
      action_id: subagentSession,
      action: String(actionName),
      turn_id: state.sticky.turn_id || (currentTurn(state) && currentTurn(state).turn_id) || '',
      start_ts: ts,
      end_ts: ts,
      duration_ms: completed && durationMs !== '' ? Number(durationMs) : undefined,
      summary: truncate(
        explicit.summary ||
          input.description ||
          input.summary ||
          state.sticky.summary ||
          actionName,
        160
      ),
      count_tool: !stopEvent,
      count_error: failureEvent,
      completed,
      status: completed ? terminalStatusOf(input) : 'running',
      recompute_tokens: true,
      transcript_path: subPath,
      token_source: 'transcript_estimate',
      subagent_session_id: subagentSession,
    });

    if (completed) {
      state.sticky = { action: '', subagent_id: '', turn_id: state.current_turn_id, written_at: Date.now() };
    }
  } else if (!stopEvent && (tool === 'Task' || tool === 'Subagent') === false) {
    // Main-chat tool activity counts on the current turn only.
    bumpTurnTools(state, failureEvent);
  }

  if (stopEvent && /^stop$/i.test(event)) {
    // Parent agent finished answering the current question.
    if (parentTranscript) {
      mergeTranscriptTurns(state, turnsFromParentTranscript(parentTranscript));
    }
    const turn = currentTurn(state);
    if (turn) {
      turn.status = 'closed';
      turn.end_ts = ts;
    }
  }

  rebuildArtifacts(dir, state);
} catch (_) {
  // fail-open
}
NODE
