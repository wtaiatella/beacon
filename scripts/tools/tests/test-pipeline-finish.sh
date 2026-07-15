#!/usr/bin/env bash
# ROAD-48: pipeline-finish git root (attach-target) + detach-workspace session safety.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
PF="$ROOT/scripts/hooks/pipeline-finish.sh"
SM="$ROOT/scripts/tools/session-memory.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

backup="$ROOT/docs/sessions/.test-pf-backup-$$"
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

orch=$(cd "$ROOT" && pwd -P)

# --- No attach: git-root is orchestrator ---
id0=$("$SM" begin-run "pf-orch-$$")
out0=$("$PF" --no-commit 2>&1) || fail "pipeline-finish --no-commit (no attach)"
printf '%s\n' "$out0" | grep -q "=== git-root ===" || fail "missing git-root section"
root_line=$(printf '%s\n' "$out0" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line" = "$orch" ] || fail "expected git-root $orch, got: $root_line"
rm -rf "$ROOT/docs/sessions/$id0"

# --- attach-target: git-root is fake target ---
fake_target=$(mktemp -d "${TMPDIR:-/tmp}/pf-fake-target.XXXXXX")
fake_canon=$(cd "$fake_target" && pwd -P)
git -C "$fake_target" init -q
echo test >"$fake_target/trackme.txt"
git -C "$fake_target" add trackme.txt
git -C "$fake_target" -c user.email=test@example.com -c user.name=test commit -q -m init
echo change >>"$fake_target/trackme.txt"

id1=$("$SM" begin-run "pf-tgt-$$")
printf '%s\n' "$fake_canon" >"$ROOT/docs/sessions/$id1/attach-target.txt"
out1=$("$PF" --no-commit 2>&1) || fail "pipeline-finish with attach"
root_line1=$(printf '%s\n' "$out1" | awk '/^=== git-root ===$/{getline; print; exit}')
[ "$root_line1" = "$fake_canon" ] || fail "attach: expected git-root $fake_canon, got $root_line1"
printf '%s\n' "$out1" | grep -q 'trackme.txt' || fail "expected target repo status to mention trackme.txt"
rm -rf "$ROOT/docs/sessions/$id1"

# --- Invalid attach-target: fail before git ---
id2=$("$SM" begin-run "pf-bad-$$")
printf '%s\n' '/no/such/path/pf-test' >"$ROOT/docs/sessions/$id2/attach-target.txt"
rc=0
"$PF" --no-commit >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "expected non-zero exit for bad attach-target"
rm -rf "$ROOT/docs/sessions/$id2"

# --- detach-workspace: only removes session.code-workspace ---
id3=$("$SM" begin-run "pf-detach-$$")
touch "$ROOT/docs/sessions/$id3/session.code-workspace"
printf '%s\n' 'keep timeline' >>"$ROOT/docs/sessions/$id3/current.md"
printf '%s\n' "$fake_canon" >"$ROOT/docs/sessions/$id3/attach-target.txt"
mkdir -p "$ROOT/docs/sessions/$id3/pre-plan"
echo x >"$ROOT/docs/sessions/$id3/pre-plan/x.txt"
"$SM" detach-workspace || fail "detach-workspace"
[ ! -f "$ROOT/docs/sessions/$id3/session.code-workspace" ] || fail "workspace file should be removed"
[ -f "$ROOT/docs/sessions/$id3/current.md" ] || fail "current.md must remain"
[ -f "$ROOT/docs/sessions/$id3/attach-target.txt" ] || fail "attach-target.txt must remain"
[ -f "$ROOT/docs/sessions/$id3/pre-plan/x.txt" ] || fail "pre-plan must remain"
rm -rf "$ROOT/docs/sessions/$id3"

cleanup
rm -rf "$fake_target"

echo "OK pipeline-finish ROAD-48 + detach-workspace tests"
