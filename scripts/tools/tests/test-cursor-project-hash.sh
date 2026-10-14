#!/usr/bin/env bash
# Unit-style tests for cursor-project-hash.sh + write-trace-anchors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
HASH="$ROOT/scripts/tools/cursor-project-hash.sh"
SM="$ROOT/scripts/tools/session-memory.sh"

# --- cursor-project-hash: help ---
bash "$HASH" --help | grep -q 'cursor-project-hash'

# --- Deterministic encoding for a temp directory ---
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cph-test.XXXXXX")
cleanup_tmp() { rm -rf "$tmp"; }
trap cleanup_tmp EXIT
abspath=$(cd "$tmp" && pwd -P)
expected=$(printf '%s\n' "${abspath#/}" | tr '.' '-' | tr '/' '-')
got=$(bash "$HASH" "$tmp")
[ "$got" = "$expected" ] || {
  echo "FAIL: expected hash '$expected', got '$got' for $tmp" >&2
  exit 1
}

# --- REPO_ROOT env ---
got2=$(REPO_ROOT="$tmp" bash "$HASH")
[ "$got2" = "$expected" ] || {
  echo "FAIL: REPO_ROOT env mismatch" >&2
  exit 1
}

# --- Nested path with dots in segment ---
mkdir -p "$tmp/with.dot/name"
nested=$(cd "$tmp/with.dot/name" && pwd -P)
exp_nested=$(printf '%s\n' "${nested#/}" | tr '.' '-' | tr '/' '-')
got_nested=$(bash "$HASH" "$tmp/with.dot/name")
[ "$got_nested" = "$exp_nested" ] || {
  echo "FAIL: nested dot path: expected '$exp_nested' got '$got_nested'" >&2
  exit 1
}

# --- --verify does not break stdout (hash only on first line) ---
first=$(bash "$HASH" --verify "$tmp" 2>/dev/null | head -1)
[ "$first" = "$expected" ]

# --- write-trace-anchors idempotence (session-memory integration) ---
TICKET="docs/specs/test-cph-$$"
cleanup_all() {
  cleanup_tmp
  rm -rf "$ROOT/$TICKET" "$fake_target"
}
fake_target=""
trap cleanup_all EXIT
mkdir -p "$ROOT/$TICKET"
sm() { "$SM" --ticket "$TICKET" "$@"; }

sm ensure >/dev/null
sm write-trace-anchors
grep -q '^SESSION_START:' "$ROOT/$TICKET/_run/timeline.md"
grep -q '^PROJECT_HASH:' "$ROOT/$TICKET/_run/timeline.md"
ph_line=$(grep '^PROJECT_HASH:' "$ROOT/$TICKET/_run/timeline.md" | head -1)
ph_val="${ph_line#PROJECT_HASH: }"
repo_hash=$(bash "$HASH" "$ROOT")
[ "$ph_val" = "$repo_hash" ]

count=$(grep -c '^SESSION_START:' "$ROOT/$TICKET/_run/timeline.md" || true)
[ "$count" -eq 1 ]

sm write-trace-anchors --resume
count2=$(grep -c '^SESSION_START:' "$ROOT/$TICKET/_run/timeline.md" || true)
[ "$count2" -eq 1 ]

# --- write-trace-anchors --resume with no anchors: must not mint new trace ---
rm -rf "$ROOT/$TICKET/_run"
sm ensure >/dev/null
sm write-trace-anchors --resume
if grep -q '^SESSION_START:' "$ROOT/$TICKET/_run/timeline.md" 2>/dev/null; then
  echo "FAIL: --resume should not write SESSION_START when anchors were absent" >&2
  exit 1
fi

# --- attach-target.txt → PROJECT_HASH + trace-hash-root use target root ---
fake_target=$(mktemp -d "${TMPDIR:-/tmp}/cph-fake-target.XXXXXX")
fake_canon=$(cd "$fake_target" && pwd -P)
printf '%s\n' "$fake_canon" >"$ROOT/$TICKET/_run/attach-target.txt"
thr=$(sm trace-hash-root)
[ "$thr" = "$fake_canon" ] || {
  echo "FAIL: trace-hash-root expected '$fake_canon' got '$thr'" >&2
  exit 1
}
sm write-trace-anchors
ph_line=$(grep '^PROJECT_HASH:' "$ROOT/$TICKET/_run/timeline.md" | head -1)
ph_val="${ph_line#PROJECT_HASH: }"
want_48=$(bash "$HASH" "$fake_canon")
[ "$ph_val" = "$want_48" ] || {
  echo "FAIL: attach PROJECT_HASH expected '$want_48' got '$ph_val'" >&2
  exit 1
}
orch=$(bash "$HASH" "$ROOT")
[ "$ph_val" != "$orch" ] || {
  echo "FAIL: expected target PROJECT_HASH to differ from orchestrator for this test" >&2
  exit 1
}

# --- Invalid attach-target path → write-trace-anchors fails ---
sm clear
printf '%s\n' '/no/such/path/road48-test' >"$ROOT/$TICKET/_run/attach-target.txt"
if sm write-trace-anchors 2>/dev/null; then
  echo "FAIL: expected write-trace-anchors to fail for missing attach directory" >&2
  exit 1
fi

echo "OK cursor-project-hash + write-trace-anchors tests"
