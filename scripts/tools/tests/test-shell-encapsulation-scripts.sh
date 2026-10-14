#!/usr/bin/env bash
# Self-tests for ROAD-52 shell wrappers: pipeline-init.sh, git-inspect.sh,
# pipeline-finish.sh, log-gate.sh (--help, invalid args, happy paths).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

PI="$ROOT/scripts/hooks/pipeline-init.sh"
GI="$ROOT/scripts/tools/git-inspect.sh"
PF="$ROOT/scripts/hooks/pipeline-finish.sh"
LG="$ROOT/scripts/tools/log-gate.sh"
SM="$ROOT/scripts/tools/session-memory.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_rc() {
  local want=$1
  shift
  local got=0
  "$@" 2>/dev/null || got=$?
  [ "$got" -eq "$want" ] || fail "expected exit $want from $* (got $got)"
}

TICKET="docs/specs/test-encap-$$"
cleanup() {
  rm -rf "$ROOT/$TICKET"
}
trap cleanup EXIT
mkdir -p "$ROOT/$TICKET"

# --- pipeline-init.sh ---
"$PI" --help | grep -qE 'pipeline-init|--ticket' || fail "pipeline-init --help"
expect_rc 1 "$PI" --not-a-flag
expect_rc 1 "$PI"

out=$("$PI" --ticket "$TICKET" 2>&1) || fail "pipeline-init happy path"
printf '%s\n' "$out" | grep -q '=== pipeline-init ===' || fail "pipeline-init missing banner"
printf '%s\n' "$out" | grep -q '=== run-dir ===' || fail "pipeline-init missing run-dir"
printf '%s\n' "$out" | grep -q '=== apply-models-snapshot ===' || fail "pipeline-init missing apply-models-snapshot"
printf '%s\n' "$out" | grep -qE 'trace-hash-root: ' || fail "pipeline-init missing trace-hash-root line"
rm -rf "$ROOT/$TICKET/_run"
rc=0
"$PI" --ticket "$TICKET" --resume >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "pipeline-init --resume without timeline (got $rc)"

# --- git-inspect.sh ---
"$GI" --help | grep -q 'git-inspect' || fail "git-inspect --help"
"$GI" --help | grep -q '\-\-repo' || fail "git-inspect --repo documented"
rc=0
"$GI" --not-an-option >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "git-inspect bad flag (got $rc)"

# Capture full stdout (avoid SIGPIPE / pipefail when grep -q closes early on large git output).
gi_out=$("$GI" 2>&1) || fail "git-inspect default run"
printf '%s\n' "$gi_out" | grep -q '=== repo ===' || fail "git-inspect repo section"
gi_scoped=$("$GI" --path .gitignore 2>&1) || fail "git-inspect scoped run"
printf '%s\n' "$gi_scoped" | grep -q '=== git-inspect' || fail "git-inspect scoped"

# --- pipeline-finish.sh ---
"$PF" --help | grep -qE 'pipeline-finish|Finish' || fail "pipeline-finish --help"
rc=0
"$PF" --bad-flag >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "pipeline-finish bad flag (got $rc)"

rc=0
"$PF" --no-commit --commit-message x >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "pipeline-finish --no-commit + commit-message should conflict (got $rc)"

pf_out=$("$PF" --no-commit 2>&1) || fail "pipeline-finish --no-commit run"
printf '%s\n' "$pf_out" | grep -qE 'audit-session-trace|audit' || fail "pipeline-finish should run audit"

# --- log-gate.sh ---
"$LG" --help | grep -qE 'log-gate|GATE' || fail "log-gate --help"
rc=0
"$LG" not-a-real-subcommand-xyz >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "log-gate unknown subcommand (got $rc)"

rc=0
"$LG" plan-done >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "log-gate plan-done arity (got $rc)"

rc=0
"$LG" impl-start >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "log-gate impl-start without --domain (got $rc)"

rc=0
"$LG" plan-done "docs/specs/x.md" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "log-gate without --ticket (got $rc)"

"$SM" --ticket "$TICKET" ensure >/dev/null || fail "ensure for log-gate"
"$LG" --ticket "$TICKET" plan-done "docs/specs/example.md" || fail "log-gate plan-done"
grep -q 'plan | DONE | spec: docs/specs/example.md' "$ROOT/$TICKET/_run/timeline.md" || fail "log-gate write"

trap - EXIT
cleanup

echo "OK shell encapsulation self-tests (pipeline-init, git-inspect, pipeline-finish, log-gate)"
exit 0
