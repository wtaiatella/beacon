#!/usr/bin/env bash
# Session-memory append order: ## Timeline, anchors, then wall-clock writes; PIPELINE last.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SM="$ROOT/scripts/tools/session-memory.sh"
backup="$ROOT/docs/sessions/.test-sm-order-active-session-backup.$$"

if [ -f "$ROOT/docs/sessions/ACTIVE_SESSION" ]; then
  cp "$ROOT/docs/sessions/ACTIVE_SESSION" "$backup"
else
  : >"$backup"
fi

cleanup() {
  if [ -f "$backup" ]; then
    if [ -s "$backup" ]; then
      cat "$backup" >"$ROOT/docs/sessions/ACTIVE_SESSION"
    else
      rm -f "$ROOT/docs/sessions/ACTIVE_SESSION"
    fi
    rm -f "$backup"
  fi
}
trap cleanup EXIT

line_after() {
  local needle="$1"
  grep -nF "$needle" "$CM" | head -1 | cut -d: -f1
}

# --- Simulated pipeline sequence: anchors → gates → context → optional finish → PIPELINE ---
id=$("$SM" begin-run "sm-order-$$")
CM="$ROOT/docs/sessions/$id/current.md"
SR="$ROOT/docs/sessions/$id"
for p in artifacts/mcp-briefs artifacts/explorer artifacts/scanners artifacts/diffs/dev artifacts/diffs/sre artifacts/diffs/data artifacts/diffs/plan; do
  [ -d "$SR/$p" ] || {
    echo "FAIL: missing ROAD-51 scaffold dir $p under session" >&2
    exit 1
  }
done

# ROAD-54: phase-security-path must be stable and distinct per phase (no overwrite across N).
p1=$("$SM" phase-security-path 1)
p2=$("$SM" phase-security-path 2)
[ "$p1" = "docs/sessions/$id/artifacts/scanners/phase-1-security.md" ] || {
  echo "FAIL: phase-security-path 1 got '$p1'" >&2
  exit 1
}
[ "$p2" = "docs/sessions/$id/artifacts/scanners/phase-2-security.md" ] || {
  echo "FAIL: phase-security-path 2 got '$p2'" >&2
  exit 1
}
[ "$p1" != "$p2" ] || {
  echo "FAIL: phase 1 and 2 paths must differ" >&2
  exit 1
}

"$SM" write-trace-anchors
"$SM" write "GATE: plan | ATTEMPT 1 | spec: docs/specs/example.md"
"$SM" write "PLAN_REVIEW_FEEDBACK: attempt 1 | fix typos"
"$SM" write "COMMIT_SUGGESTIONS: user chose m1"
"$SM" write "PIPELINE: COMPLETE"

grep -q '^## Timeline$' "$CM" || {
  echo "FAIL: missing ## Timeline header" >&2
  exit 1
}

lt=$(line_after '## Timeline')
ss=$(line_after 'SESSION_START:')
ph=$(line_after 'PROJECT_HASH:')
# Bullets are "- ts | …"; match unique substrings
g1=$(line_after '| plan | ATTEMPT 1 | spec:')
pr=$(line_after 'PLAN_REVIEW_FEEDBACK:')
cs=$(line_after 'COMMIT_SUGGESTIONS:')
pc=$(line_after '| PIPELINE: COMPLETE')

# Strictly increasing line numbers (append-only chronology at file level)
[ "$lt" -lt "$ss" ] || {
  echo "FAIL: Timeline must precede SESSION_START (lt=$lt ss=$ss)" >&2
  exit 1
}
[ "$ss" -lt "$ph" ] || {
  echo "FAIL: SESSION_START must precede PROJECT_HASH" >&2
  exit 1
}
[ "$ph" -lt "$g1" ] || {
  echo "FAIL: anchors must precede GATE write" >&2
  exit 1
}
[ "$g1" -lt "$pr" ] || {
  echo "FAIL: GATE must precede PLAN_REVIEW_FEEDBACK" >&2
  exit 1
}
[ "$pr" -lt "$cs" ] || {
  echo "FAIL: feedback must precede COMMIT_SUGGESTIONS" >&2
  exit 1
}
[ "$cs" -lt "$pc" ] || {
  echo "FAIL: COMMIT_SUGGESTIONS must precede PIPELINE: COMPLETE" >&2
  exit 1
}

# Last non-empty line must be the PIPELINE bullet
last_meaningful=$(grep -v '^[[:space:]]*$' "$CM" | tail -1)
case "$last_meaningful" in
  *PIPELINE:*COMPLETE*) ;;
  *)
    echo "FAIL: last meaningful line should contain PIPELINE: COMPLETE, got: $last_meaningful" >&2
    exit 1
    ;;
esac

rm -rf "$ROOT/docs/sessions/$id"

# --- DECISION / QUESTION / GATE typed prefixes still append in call order ---
id2=$("$SM" begin-run "sm-order2-$$")
CM="$ROOT/docs/sessions/$id2/current.md"
"$SM" write "DECISION: pick A"
"$SM" write "QUESTION: clarify B?"
"$SM" write "GATE: plan-review | 80% | PROCEED | attempts: 1"
d=$(line_after '| pick A')
q=$(line_after '| clarify B?')
g=$(line_after '| plan-review | 80%')
[ "$d" -lt "$q" ] && [ "$q" -lt "$g" ] || {
  echo "FAIL: DECISION/QUESTION/GATE order" >&2
  exit 1
}
rm -rf "$ROOT/docs/sessions/$id2"

echo "OK session-memory ordering tests"
