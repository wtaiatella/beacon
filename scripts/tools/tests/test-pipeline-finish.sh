#!/usr/bin/env bash
# pipeline-finish git root (attach-target) + detach-workspace safety.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
PF="$ROOT/scripts/hooks/pipeline-finish.sh"
SM="$ROOT/scripts/tools/session-memory.sh"
TICKET="docs/specs/test-pf-$$"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

cleanup() {
  rm -rf "$ROOT/$TICKET" "$fake_target"
}
fake_target=""
trap cleanup EXIT
mkdir -p "$ROOT/$TICKET"

orch=$(cd "$ROOT" && pwd -P)

# --- No ticket: git-root is orchestrator ---
out0=$("$PF" --no-commit 2>&1) || fail "pipeline-finish --no-commit (no attach)"
printf '%s\n' "$out0" | grep -q "=== git-root ===" || fail "missing git-root section"
root_line=$(printf '%s\n' "$out0" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line" = "$orch" ] || fail "expected git-root $orch, got: $root_line"

# --- attach-target: git-root is fake target ---
fake_target=$(mktemp -d "${TMPDIR:-/tmp}/pf-fake-target.XXXXXX")
fake_canon=$(cd "$fake_target" && pwd -P)
git -C "$fake_target" init -q
echo test >"$fake_target/trackme.txt"
git -C "$fake_target" add trackme.txt
git -C "$fake_target" -c user.email=test@example.com -c user.name=test commit -q -m init
echo change >>"$fake_target/trackme.txt"

"$SM" --ticket "$TICKET" ensure >/dev/null
printf '%s\n' "$fake_canon" >"$ROOT/$TICKET/_run/attach-target.txt"
out1=$("$PF" --ticket "$TICKET" --no-commit 2>&1) || fail "pipeline-finish with attach"
root_line1=$(printf '%s\n' "$out1" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line1" = "$fake_canon" ] || fail "attach: expected git-root $fake_canon, got $root_line1"
printf '%s\n' "$out1" | grep -q 'trackme.txt' || fail "expected target repo status to mention trackme.txt"

# --- Invalid attach-target: fail before git ---
printf '%s\n' '/no/such/path/pf-test' >"$ROOT/$TICKET/_run/attach-target.txt"
rc=0
"$PF" --ticket "$TICKET" --no-commit >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "expected non-zero exit for bad attach-target"

# --- detach-workspace: only removes session.code-workspace ---
touch "$ROOT/$TICKET/_run/session.code-workspace"
printf '%s\n' 'keep timeline' >>"$ROOT/$TICKET/_run/timeline.md"
printf '%s\n' "$fake_canon" >"$ROOT/$TICKET/_run/attach-target.txt"
mkdir -p "$ROOT/$TICKET/_run/pre-plan"
echo x >"$ROOT/$TICKET/_run/pre-plan/x.txt"
"$SM" --ticket "$TICKET" detach-workspace || fail "detach-workspace"
[ ! -f "$ROOT/$TICKET/_run/session.code-workspace" ] || fail "workspace file should be removed"
[ -f "$ROOT/$TICKET/_run/timeline.md" ] || fail "timeline.md must remain"
[ -f "$ROOT/$TICKET/_run/attach-target.txt" ] || fail "attach-target.txt must remain"
[ -f "$ROOT/$TICKET/_run/pre-plan/x.txt" ] || fail "pre-plan must remain"

echo "OK pipeline-finish attach-target + detach-workspace tests"
