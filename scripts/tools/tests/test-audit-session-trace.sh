#!/usr/bin/env bash
# Fixture tests for audit-session-trace.py.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
AUDIT="$ROOT/scripts/tools/audit-session-trace.py"

python3 "$AUDIT" --help | grep -q 'audit-session-trace'
python3 "$AUDIT" --help | grep -q -- '--forbid-substrings'
python3 "$AUDIT" --help | grep -q -- '--require-agent-role'
python3 "$AUDIT" --help | grep -q -- '--exit-on-forbid'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/ast-test.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

fake_home="$tmp/home"
sid="2026-04-10T120000Z-audit-test"
mkdir -p "$tmp/ws/docs/sessions/$sid"
mkdir -p "$fake_home/.cursor/projects/TestProjectHashHere/agent-transcripts"

# Anchors: SESSION_START in the past so our jsonl (touched now) qualifies.
cat >"$tmp/ws/docs/sessions/$sid/current.md" <<'EOF'
# Session Memory
## Context

SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: TestProjectHashHere
EOF

cat >"$fake_home/.cursor/projects/TestProjectHashHere/agent-transcripts/sample.jsonl" <<'EOF'
{"usage":{"total_tokens":99,"prompt_tokens":10}}
{"role":"system","content":"Short system reminder for the agent."}
not valid json on purpose
{"file":"/home/user/repo/src/main.py"}
EOF
touch "$fake_home/.cursor/projects/TestProjectHashHere/agent-transcripts/sample.jsonl"

python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$fake_home" >/dev/null

log="$tmp/ws/docs/sessions/$sid/context-audit.log"
test -f "$log" || {
  echo "FAIL: context-audit.log missing" >&2
  exit 1
}
grep -q 'append-only Finish sections' "$log" || {
  echo "FAIL: expected log banner" >&2
  exit 1
}
grep -q 'total_tokens=99' "$log" || {
  echo "FAIL: expected token extraction" >&2
  exit 1
}
grep -q 'malformed JSON' "$log" || {
  echo "FAIL: expected malformed line note" >&2
  exit 1
}
grep -q '/home/user/repo/src/main.py' "$log" || {
  echo "FAIL: expected path extraction" >&2
  exit 1
}

# Nested-only .jsonl (ROAD-49: rglob under agent-transcripts, not only top-level glob)
nested_sid="2026-04-11T000000Z-nested-only"
mkdir -p "$tmp/ws/docs/sessions/$nested_sid"
mkdir -p "$fake_home/.cursor/projects/NestedHash/agent-transcripts/nested/uuid-sub"
cat >"$tmp/ws/docs/sessions/$nested_sid/current.md" <<'EOF'
# Session Memory

SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: NestedHash
EOF
printf '%s\n' '{"usage":{"total_tokens":7}}' \
  >"$fake_home/.cursor/projects/NestedHash/agent-transcripts/nested/uuid-sub/only-nested.jsonl"
touch "$fake_home/.cursor/projects/NestedHash/agent-transcripts/nested/uuid-sub/only-nested.jsonl"
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$nested_sid" --home "$fake_home" >/dev/null
nested_log="$tmp/ws/docs/sessions/$nested_sid/context-audit.log"
grep -q 'total_tokens=7' "$nested_log" || {
  echo "FAIL: expected token extraction from nested-only jsonl" >&2
  exit 1
}
grep -q 'only-nested.jsonl' "$nested_log" || {
  echo "FAIL: expected nested transcript filename in Finish payload" >&2
  exit 1
}

# Missing transcript dir: non-strict exits 0 (HOME exists; ~/.cursor/projects/<hash> absent)
mkdir -p "$tmp/empty_home"
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$tmp/empty_home" >/dev/null
ec=0
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$tmp/empty_home" --strict 2>/dev/null || ec=$?
[ "$ec" -eq 2 ] || {
  echo "FAIL: expected exit 2 for --strict with missing dir" >&2
  exit 1
}

# No jsonl in window: create old file
mkdir -p "$fake_home/.cursor/projects/EmptyWindow/agent-transcripts"
echo 'SESSION_START: 2099-01-01T00:00:00.000Z
PROJECT_HASH: EmptyWindow' >"$tmp/ws/docs/sessions/$sid/current.md"
echo '{}' >"$fake_home/.cursor/projects/EmptyWindow/agent-transcripts/old.jsonl"
touch -t 200001010000 "$fake_home/.cursor/projects/EmptyWindow/agent-transcripts/old.jsonl"

ec=0
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$fake_home" --strict 2>/dev/null || ec=$?
[ "$ec" -eq 2 ] || {
  echo "FAIL: strict empty window should exit 2" >&2
  exit 1
}

grep -Fq -- '--- diagnostic: zero matches in SESSION_START window (after 60s IDE buffer) ---' "$log" || {
  echo "FAIL: expected zero-match diagnostic banner in context-audit.log" >&2
  exit 1
}
grep -Fq 'mtime_utc=' "$log" || {
  echo "FAIL: expected mtime_utc listing in diagnostics" >&2
  exit 1
}

# Second session directory (newer current.md mtime) for --prior-session-hints
prior_id="2026-04-11T000000Z-prior-hint"
mkdir -p "$tmp/ws/docs/sessions/$prior_id"
printf '%s\n' '# Session Memory' '## Context' '' \
  'SESSION_START: 2025-06-01T12:00:00.000Z' \
  'PROJECT_HASH: PriorHintHash' >"$tmp/ws/docs/sessions/$prior_id/current.md"
touch "$tmp/ws/docs/sessions/$prior_id/current.md"

python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$fake_home" \
  --stdout --prior-session-hints | grep -q 'Prior session hints' || {
  echo "FAIL: expected prior session hints on stdout" >&2
  exit 1
}
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$fake_home" \
  --stdout --prior-session-hints | grep -q 'PriorHintHash' || {
  echo "FAIL: expected PROJECT_HASH from prior session in hints" >&2
  exit 1
}

# --pre-audit-delay-seconds 0 should behave like default (still zero-match + diagnostics)
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$sid" --home "$fake_home" \
  --stdout --pre-audit-delay-seconds 0 | grep -Fq -- 'diagnostic: zero matches' || {
  echo "FAIL: pre-audit-delay-seconds 0 should still emit diagnostics on zero-match" >&2
  exit 1
}

# --- Forbid / LPP-style QA checks (ROAD-51 Phase 4) ---
forbid_sid="2026-04-11T120000Z-forbid-lpp"
mkdir -p "$tmp/ws/docs/sessions/$forbid_sid"
mkdir -p "$fake_home/.cursor/projects/ForbidHash/agent-transcripts/dev"
mkdir -p "$fake_home/.cursor/projects/ForbidHash/agent-transcripts/qa"
cat >"$tmp/ws/docs/sessions/$forbid_sid/current.md" <<'EOF'
SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: ForbidHash
EOF
# Dev transcript: forbidden markers (must NOT count when scoped to qa only)
printf '%s\n' '{"role":"user","content":"read docs/sessions/x/artifacts/mcp-briefs/merged.md"}' \
  >"$fake_home/.cursor/projects/ForbidHash/agent-transcripts/dev/dev.jsonl"
touch "$fake_home/.cursor/projects/ForbidHash/agent-transcripts/dev/dev.jsonl"
# QA transcript: path segment qa/ + leakage markers
printf '%s\n' '{"role":"assistant","content":"pre-plan/specialists/glean.md should not appear; mcp-briefs bad"}' \
  >"$fake_home/.cursor/projects/ForbidHash/agent-transcripts/qa/qa-child.jsonl"
touch "$fake_home/.cursor/projects/ForbidHash/agent-transcripts/qa/qa-child.jsonl"

python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$forbid_sid" --home "$fake_home" \
  --forbid-substrings 'mcp-briefs,pre-plan/specialists' --require-agent-role qa >/dev/null

forbid_log="$tmp/ws/docs/sessions/$forbid_sid/context-audit.log"
grep -Fq -- '--- optional forbid check (raw JSONL substring scan) ---' "$forbid_log" || {
  echo "FAIL: expected forbid section banner in context-audit.log" >&2
  exit 1
}
grep -Fq 'MATCHES (forbidden substring appears in scoped file text):' "$forbid_log" || {
  echo "FAIL: expected MATCHES line in forbid section" >&2
  exit 1
}
grep -Fq "pattern='pre-plan/specialists'" "$forbid_log" || {
  echo "FAIL: expected pre-plan/specialists pattern hit in log" >&2
  exit 1
}
grep -Fq "Status: WARN: forbidden substring" "$forbid_log" || {
  echo "FAIL: expected WARN status for forbid violation (no --exit-on-forbid)" >&2
  exit 1
}

ec=0
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$forbid_sid" --home "$fake_home" \
  --forbid-substrings mcp-briefs --require-agent-role qa --exit-on-forbid >/dev/null 2>&1 || ec=$?
[ "$ec" -eq 3 ] || {
  echo "FAIL: expected exit 3 for --exit-on-forbid when QA transcript matches" >&2
  exit 1
}

# Dev-only marker: with --require-agent-role qa, dev file must not trigger forbid
dev_only_sid="2026-04-11T120001Z-forbid-devonly"
mkdir -p "$tmp/ws/docs/sessions/$dev_only_sid"
mkdir -p "$fake_home/.cursor/projects/DevOnlyHash/agent-transcripts/dev"
cat >"$tmp/ws/docs/sessions/$dev_only_sid/current.md" <<'EOF'
SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: DevOnlyHash
EOF
printf '%s\n' '{"content":"artifacts/mcp-briefs/x"}' \
  >"$fake_home/.cursor/projects/DevOnlyHash/agent-transcripts/dev/only-dev.jsonl"
touch "$fake_home/.cursor/projects/DevOnlyHash/agent-transcripts/dev/only-dev.jsonl"

python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$dev_only_sid" --home "$fake_home" \
  --forbid-substrings mcp-briefs --require-agent-role qa --stdout | grep -Fq 'MATCHES: (none)' || {
  echo "FAIL: qa-scoped forbid should find no matches when only dev transcript has marker" >&2
  exit 1
}

# subagent_type in JSON (filename not containing qa) — still scoped as qa
meta_sid="2026-04-11T120002Z-forbid-meta"
mkdir -p "$tmp/ws/docs/sessions/$meta_sid"
mkdir -p "$fake_home/.cursor/projects/MetaHash/agent-transcripts/nested"
cat >"$tmp/ws/docs/sessions/$meta_sid/current.md" <<'EOF'
SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: MetaHash
EOF
printf '%s\n' '{"subagent_type":"qa","role":"user","content":"ok"}' \
  '{"role":"assistant","content":"See mcp-briefs in prompt"}' \
  >"$fake_home/.cursor/projects/MetaHash/agent-transcripts/nested/transcript.jsonl"
touch "$fake_home/.cursor/projects/MetaHash/agent-transcripts/nested/transcript.jsonl"

python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$meta_sid" --home "$fake_home" \
  --forbid-substrings mcp-briefs --require-agent-role qa --stdout | grep -Fq "pattern='mcp-briefs'" || {
  echo "FAIL: expected subagent_type qa file to be scanned for forbid" >&2
  exit 1
}

# ROAD-51 / QA: reject path-like session id and unsafe PROJECT_HASH (exit 1)
set +e
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id '../evil' --home "$fake_home" >/dev/null 2>&1
ec_bad_sid=$?
set -e
[ "$ec_bad_sid" -eq 1 ] || {
  echo "FAIL: expected exit 1 for invalid --session-id, got $ec_bad_sid" >&2
  exit 1
}

badph_sid="2026-04-11T120003Z-bad-ph"
mkdir -p "$tmp/ws/docs/sessions/$badph_sid"
cat >"$tmp/ws/docs/sessions/$badph_sid/current.md" <<'EOF'
SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: evil/hash
EOF
set +e
python3 "$AUDIT" --workspace-root "$tmp/ws" --session-id "$badph_sid" --home "$fake_home" >/dev/null 2>&1
ec_bad_ph=$?
set -e
[ "$ec_bad_ph" -eq 1 ] || {
  echo "FAIL: expected exit 1 for invalid PROJECT_HASH, got $ec_bad_ph" >&2
  exit 1
}

echo "OK audit-session-trace tests"
