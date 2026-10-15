#!/usr/bin/env bash
# Smoke test for session-handoff.sh + session-memory session-root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SM="$ROOT/scripts/tools/session-memory.sh"
SH="$ROOT/scripts/tools/session-handoff.sh"
TICKET="docs/specs/test-handoff-$$"

cleanup() {
  rm -rf "$ROOT/$TICKET"
}
trap cleanup EXIT
mkdir -p "$ROOT/$TICKET"
"$SM" --ticket "$TICKET" ensure >/dev/null

tmpdir=$(mktemp)
printf '%s\n' 'snapshot line' >"$tmpdir"
"$SH" --ticket "$TICKET" write-handoff merged "$tmpdir" >/dev/null
"$SH" --ticket "$TICKET" write-handoff specialist jira "$tmpdir" >/dev/null
"$SH" --ticket "$TICKET" write-handoff review "$tmpdir" >/dev/null
"$SH" --ticket "$TICKET" write-handoff gate "$tmpdir" >/dev/null
rm -f "$tmpdir"

test -f "$ROOT/$TICKET/pre-plan/merged-brief.md"
test -f "$ROOT/$TICKET/pre-plan/specialists/jira.md"
test -f "$ROOT/$TICKET/pre-plan/review.md"
test -f "$ROOT/$TICKET/pre-plan/gate.md"
test ! -d "$ROOT/$TICKET/_run/pre-plan"
grep -q '^kind: merged-brief' "$ROOT/$TICKET/pre-plan/merged-brief.md"
grep -q '^specialist: jira' "$ROOT/$TICKET/pre-plan/specialists/jira.md"
grep -q '^kind: review' "$ROOT/$TICKET/pre-plan/review.md"
grep -q '^kind: gate' "$ROOT/$TICKET/pre-plan/gate.md"
grep -q 'snapshot line' "$ROOT/$TICKET/pre-plan/merged-brief.md"

rel=$("$SM" --ticket "$TICKET" session-root)
[ "$rel" = "$TICKET/_run" ]

echo "OK session-handoff smoke test"
