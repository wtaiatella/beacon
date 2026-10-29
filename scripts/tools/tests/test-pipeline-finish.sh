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

# --- _state.json repo fallback (when attach-target.txt is absent) ---
rm -f "$ROOT/$TICKET/_run/attach-target.txt"
cat >"$ROOT/$TICKET/_state.json" <<EOF
{
  "ticket": "TEST-1",
  "repo": "$fake_canon",
  "branch": "fix/TEST-1"
}
EOF
out_state=$("$PF" --ticket "$TICKET" --no-commit 2>&1) || fail "pipeline-finish with _state.json repo"
root_line_state=$(printf '%s\n' "$out_state" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line_state" = "$fake_canon" ] || fail "_state.json repo: expected $fake_canon, got $root_line_state"

# --- --repo flag overrides _state.json ---
out_repo_flag=$("$PF" --ticket "$TICKET" --repo "$fake_canon" --no-commit 2>&1) || fail "pipeline-finish with --repo"
root_line_flag=$(printf '%s\n' "$out_repo_flag" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line_flag" = "$fake_canon" ] || fail "--repo: expected $fake_canon, got $root_line_flag"

# --- Invalid _state.json repo fails closed (does not fall back to $ROOT) ---
cat >"$ROOT/$TICKET/_state.json" <<EOF
{
  "ticket": "TEST-1",
  "repo": "non-existent-child-repo-xyz"
}
EOF
rc=0
"$PF" --ticket "$TICKET" --no-commit >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "expected non-zero exit for missing _state.json repo"
rm -f "$ROOT/$TICKET/_state.json"

# --- detach-workspace: only removes session.code-workspace ---
touch "$ROOT/$TICKET/_run/session.code-workspace"
printf '%s\n' 'keep timeline' >>"$ROOT/$TICKET/_run/timeline.md"
printf '%s\n' "$fake_canon" >"$ROOT/$TICKET/_run/attach-target.txt"
mkdir -p "$ROOT/$TICKET/pre-plan"
echo x >"$ROOT/$TICKET/pre-plan/x.txt"
"$SM" --ticket "$TICKET" detach-workspace || fail "detach-workspace"
[ ! -f "$ROOT/$TICKET/_run/session.code-workspace" ] || fail "workspace file should be removed"
[ -f "$ROOT/$TICKET/_run/timeline.md" ] || fail "timeline.md must remain"
[ -f "$ROOT/$TICKET/_run/attach-target.txt" ] || fail "attach-target.txt must remain"
[ -f "$ROOT/$TICKET/pre-plan/x.txt" ] || fail "pre-plan must remain"

echo "OK pipeline-finish attach-target + detach-workspace tests"
