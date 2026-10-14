#!/usr/bin/env bash
# Run-timeline append order: ## Timeline, anchors, then wall-clock writes; PIPELINE last.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SM="$ROOT/scripts/tools/session-memory.sh"
TICKET="docs/specs/test-sm-order-$$"

cleanup() {
  rm -rf "$ROOT/$TICKET"
}
trap cleanup EXIT
mkdir -p "$ROOT/$TICKET"

line_after() {
  local needle="$1"
  grep -nF "$needle" "$CM" | head -1 | cut -d: -f1
}

sm() {
  "$SM" --ticket "$TICKET" "$@"
}

# --- Simulated pipeline sequence: anchors → gates → context → optional finish → PIPELINE ---
sm ensure >/dev/null
CM="$ROOT/$TICKET/_run/timeline.md"
SR="$ROOT/$TICKET/_run"
for p in pre-plan/specialists explorer scanners diffs/dev diffs/sre diffs/data diffs/plan; do
  [ -d "$SR/$p" ] || {
    echo "FAIL: missing scaffold dir $p under _run" >&2
    exit 1
  }
done

p1=$(sm phase-security-path 1)
p2=$(sm phase-security-path 2)
[ "$p1" = "$TICKET/_run/scanners/phase-1-security.md" ] || {
  echo "FAIL: phase-security-path 1 got '$p1'" >&2
  exit 1
}
[ "$p2" = "$TICKET/_run/scanners/phase-2-security.md" ] || {
  echo "FAIL: phase-security-path 2 got '$p2'" >&2
  exit 1
}
[ "$p1" != "$p2" ] || {
  echo "FAIL: phase 1 and 2 paths must differ" >&2
  exit 1
}

sm write-trace-anchors
sm write "GATE: plan | ATTEMPT 1 | spec: docs/specs/example.md"
sm write "PLAN_REVIEW_FEEDBACK: attempt 1 | fix typos"
sm write "COMMIT_SUGGESTIONS: user chose m1"
sm write "PIPELINE: COMPLETE"

grep -q '^## Timeline$' "$CM" || {
  echo "FAIL: missing ## Timeline header" >&2
  exit 1
}

lt=$(line_after '## Timeline')
ss=$(line_after 'SESSION_START:')
ph=$(line_after 'PROJECT_HASH:')
g1=$(line_after '| plan | ATTEMPT 1 | spec:')
pr=$(line_after 'PLAN_REVIEW_FEEDBACK:')
cs=$(line_after 'COMMIT_SUGGESTIONS:')
pc=$(line_after '| PIPELINE: COMPLETE')

[ "$lt" -lt "$ss" ] || {
  echo "FAIL: ## Timeline must precede SESSION_START" >&2
  exit 1
}
[ "$ss" -lt "$ph" ] || {
  echo "FAIL: SESSION_START must precede PROJECT_HASH" >&2
  exit 1
}
[ "$ph" -lt "$g1" ] || {
  echo "FAIL: PROJECT_HASH must precede the first gate write" >&2
  exit 1
}
[ "$g1" -lt "$pr" ] || {
  echo "FAIL: plan attempt must precede PLAN_REVIEW_FEEDBACK" >&2
  exit 1
}
[ "$pr" -lt "$cs" ] || {
  echo "FAIL: PLAN_REVIEW_FEEDBACK must precede COMMIT_SUGGESTIONS" >&2
  exit 1
}
[ "$cs" -lt "$pc" ] || {
  echo "FAIL: COMMIT_SUGGESTIONS must precede PIPELINE: COMPLETE" >&2
  exit 1
}

last_meaningful=$(grep -v '^[[:space:]]*$' "$CM" | tail -1)
case "$last_meaningful" in
  *PIPELINE:*COMPLETE*) ;;
  *)
    echo "FAIL: last meaningful line should contain PIPELINE: COMPLETE, got: $last_meaningful" >&2
    exit 1
    ;;
esac

# --- DECISION / QUESTION / GATE typed prefixes still append in call order ---
rm -rf "$ROOT/$TICKET/_run"
sm ensure >/dev/null
CM="$ROOT/$TICKET/_run/timeline.md"
sm write "DECISION: pick A"
sm write "QUESTION: clarify B?"
sm write "GATE: plan-review | 80% | PROCEED | attempts: 1"
d=$(line_after '| pick A')
q=$(line_after '| clarify B?')
g=$(line_after '| plan-review | 80%')
[ "$d" -lt "$q" ] && [ "$q" -lt "$g" ] || {
  echo "FAIL: DECISION/QUESTION/GATE order" >&2
  exit 1
}

echo "OK session-memory ordering tests"
