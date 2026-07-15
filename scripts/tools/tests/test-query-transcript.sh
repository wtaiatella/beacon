#!/usr/bin/env bash
# Fixture tests for query-transcript.py (read-only JSONL query; ROAD-55 Phase 1).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
QT="$ROOT/scripts/tools/query-transcript.py"

python3 "$QT" --help | grep -q 'query-transcript'
python3 "$QT" --help | grep -q -- '--transcript-root'
python3 "$QT" --help | grep -q 'QUERY_TRANSCRIPT_ROOT'
python3 "$QT" --help | grep -q -- '--grep'
python3 "$QT" --help | grep -q -- '--role'
python3 "$QT" --help | grep -q -- '--max-scan-lines-no-match'
python3 "$QT" --help | grep -q -- '--max-scan-bytes-no-match'
python3 "$QT" --help | grep -q -- '--max-jsonl-line-chars'

tmp=$(mktemp -d "${TMPDIR:-/tmp}/qt-test.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

sid="2026-04-11T120000Z-query-test"
mkdir -p "$tmp/ws/docs/sessions/$sid"
mkdir -p "$tmp/transcripts"

cat >"$tmp/ws/docs/sessions/$sid/current.md" <<'EOF'
# Session Memory
SESSION_START: 2026-01-01T00:00:00.000Z
PROJECT_HASH: IrrelevantWhenOverride
EOF

cat >"$tmp/transcripts/chat.jsonl" <<'EOF'
{"role":"system","content":"hidden from both filter"}
{"role":"user","content":"Hello from user"}
{"role":"assistant","content":"Reply without magicword"}
{"role":"assistant","content":"Second line with MAGICWORD in it"}
EOF

out=$(python3 "$QT" --workspace-root "$tmp/ws" --session-id "$sid" --transcript-root "$tmp/transcripts")
echo "$out" | grep -q 'Hello from user' || {
  echo "FAIL: expected user line" >&2
  exit 1
}
echo "$out" | grep -q 'MAGICWORD' || {
  echo "FAIL: expected assistant magic line" >&2
  exit 1
}
echo "$out" | grep -q 'hidden from both' && {
  echo "FAIL: system line should not appear for role=both" >&2
  exit 1
}

out2=$(python3 "$QT" --workspace-root "$tmp/ws" --session-id "$sid" --transcript-root "$tmp/transcripts" --role assistant --grep MAGICWORD)
echo "$out2" | grep -q 'MAGICWORD' || {
  echo "FAIL: grep filter" >&2
  exit 1
}
echo "$out2" | grep -q 'Reply without magicword' && {
  echo "FAIL: grep should exclude non-matching assistant line" >&2
  exit 1
}

# QUERY_TRANSCRIPT_ROOT relative to workspace
export QUERY_TRANSCRIPT_ROOT="transcripts-fix"
mkdir -p "$tmp/ws/transcripts-fix"
cp "$tmp/transcripts/chat.jsonl" "$tmp/ws/transcripts-fix/"
out3=$(cd "$tmp/ws" && python3 "$QT" --workspace-root "$tmp/ws" --session-id "$sid")
echo "$out3" | grep -q 'Hello from user' || {
  echo "FAIL: QUERY_TRANSCRIPT_ROOT relative path" >&2
  exit 1
}
unset QUERY_TRANSCRIPT_ROOT

# Nested .jsonl (same rglob pattern as audit-session-trace)
mkdir -p "$tmp/transcripts/nested/uuid"
printf '%s\n' '{"role":"user","content":"nested only"}' >"$tmp/transcripts/nested/uuid/n.jsonl"
out4=$(python3 "$QT" --workspace-root "$tmp/ws" --session-id "$sid" --transcript-root "$tmp/transcripts" --grep nested)
echo "$out4" | grep -q 'nested only' || {
  echo "FAIL: expected nested jsonl" >&2
  exit 1
}

# Invalid session id → exit 1
set +e
python3 "$QT" --workspace-root "$tmp/ws" --session-id '../evil' --transcript-root "$tmp/transcripts" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" -eq 1 ] || {
  echo "FAIL: expected exit 1 for bad session id, got $ec" >&2
  exit 1
}

# --strict + missing transcript dir
mkdir -p "$tmp/ws/docs/sessions/2026-04-11T120001Z-strict"
mkdir -p "$tmp/emptyhome"
printf '%s\n' '# x' 'SESSION_START: 2026-01-01T00:00:00.000Z' 'PROJECT_HASH: NoSuchDirHash' \
  >"$tmp/ws/docs/sessions/2026-04-11T120001Z-strict/current.md"
set +e
python3 "$QT" --workspace-root "$tmp/ws" --session-id "2026-04-11T120001Z-strict" \
  --home "$tmp/emptyhome" --strict >/dev/null 2>&1
ec_st=$?
set -e
[ "$ec_st" -eq 2 ] || {
  echo "FAIL: expected exit 2 for --strict missing ~/.cursor tree, got $ec_st" >&2
  exit 1
}

# No-match scan cap: many system lines, --role user, low line budget → bounded read + stderr
mkdir -p "$tmp/transcripts-huge"
: >"$tmp/transcripts-huge/many.jsonl"
for _ in $(seq 1 80); do
  printf '%s\n' '{"role":"system","content":"x"}' >>"$tmp/transcripts-huge/many.jsonl"
done
printf '%s\n' '{"role":"user","content":"only after cap"}' >>"$tmp/transcripts-huge/many.jsonl"
set +e
err=$(python3 "$QT" --workspace-root "$tmp/ws" --session-id "$sid" \
  --transcript-root "$tmp/transcripts-huge" --role user --max-scan-lines-no-match 50 2>&1 >/dev/null)
ec_huge=$?
set -e
[ "$ec_huge" -eq 0 ] || {
  echo "FAIL: expected exit 0 for scan cap case, got $ec_huge" >&2
  exit 1
}
echo "$err" | grep -q 'scan cap (no matching lines yet)' || {
  echo "FAIL: expected scan cap stderr" >&2
  exit 1
}

echo "OK query-transcript tests"
