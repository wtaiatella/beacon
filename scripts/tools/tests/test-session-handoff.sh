#!/usr/bin/env bash
# Smoke test for session-handoff.sh + session-memory session-root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SM="$ROOT/scripts/tools/session-memory.sh"
SH="$ROOT/scripts/tools/session-handoff.sh"
backup="$ROOT/docs/sessions/.test-active-session-backup.$$"

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

# begin-run matches new-session allocation; exercise begin-run in smoke test
id=$("$SM" begin-run "smoke-handoff-$$")
tmpdir=$(mktemp)
printf '%s\n' 'snapshot line' >"$tmpdir"
"$SH" write-handoff merged "$tmpdir" >/dev/null
"$SH" write-handoff specialist arc "$tmpdir" >/dev/null
rm -f "$tmpdir"

test -f "$ROOT/docs/sessions/$id/pre-plan/merged-brief.md"
test -f "$ROOT/docs/sessions/$id/pre-plan/specialists/arc.md"
grep -q '^kind: merged-brief' "$ROOT/docs/sessions/$id/pre-plan/merged-brief.md"
grep -q '^specialist: arc' "$ROOT/docs/sessions/$id/pre-plan/specialists/arc.md"
grep -q 'snapshot line' "$ROOT/docs/sessions/$id/pre-plan/merged-brief.md"

rel=$("$SM" session-root)
[ "$rel" = "docs/sessions/$id" ]

rm -rf "$ROOT/docs/sessions/$id"
echo "OK session-handoff smoke test"
