#!/usr/bin/env bash
# Blocking doc checks for: begin-run session rotation, Task(do) for authorized spec
# updates, Non-negotiable 8 guardrail (no main-session *.md bookkeeping), router Task(do) clarity.
# Modeled after verify-qa-git-boundaries.sh.
# Run from repo root: ./scripts/tools/verify-taskdo-session-boundaries.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SKILL="agentic/skills/run-pipeline/SKILL.md"
SESSION_MEM="scripts/tools/session-memory.sh"
ROUTER="agentic/adapters/cursor/rules/00-workspace-router.mdc"

echo "verify-taskdo-session-boundaries: repo root=$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test -f "$SKILL" || fail "missing $SKILL"
test -f "$SESSION_MEM" || fail "missing $SESSION_MEM"
test -f "$ROUTER" || fail "missing $ROUTER"

# --- run-pipeline SKILL: ticket-scoped run dir ---
grep -qF 'pipeline-init.sh' "$SKILL" || fail "SKILL must document pipeline-init.sh"
grep -qF -- '--ticket' "$SKILL" || fail "SKILL must pass --ticket to the run-state scripts"

# --- SKILL: Task(do) for authorized spec updates ---
grep -qF '#### Task(do) for authorized spec updates' "$SKILL" \
  || fail "SKILL must have heading Task(do) for authorized spec updates"
grep -qF 'Task(do) for authorized spec updates' "$SKILL" \
  || fail "SKILL must reference Task(do) for authorized spec updates"

# --- SKILL: Non-negotiable 8 — no main-session *.md pipeline bookkeeping ---
grep -qF '**No direct Markdown edits' "$SKILL" \
  || fail "SKILL must document Non-negotiable 8 markdown guardrail"
grep -qE '\*\.md|apply_patch' "$SKILL" \
  || fail "SKILL must forbid main-session *.md / apply_patch style edits for bookkeeping"

# --- session-memory.sh: ticket folder is the run identity ---
grep -qF -- '--ticket' "$SESSION_MEM" || fail "session-memory.sh must require --ticket"
grep -qF 'ensure)' "$SESSION_MEM" || fail "session-memory.sh must dispatch ensure"
if grep -qE '^[[:space:]]*begin-run\)' "$SESSION_MEM"; then
  fail "session-memory.sh must not dispatch begin-run"
fi

# --- 00-workspace-router.mdc: Task(do) after scrum for spec updates (not patches-only wording) ---
grep -qF 'Task(do)' "$ROUTER" || fail "router must mention Task(do)"
grep -qF 'Task(scrum)' "$ROUTER" || fail "router must mention Task(scrum)"
grep -qE 'Proposed spec updates.*Task\(scrum\)|Task\(scrum\).*PROCEED.*Task\(do\)|Task\(do\).*Task\(scrum\)' "$ROUTER" \
  || fail "router must tie Task(do) spec application to Task(scrum) PROCEED"
grep -qE 'orchestrator applies patches|main session.*must not.*patch|apply_patch' "$ROUTER" \
  || fail "router should document that main session does not patch specs (orchestrator/Task(do) split)"

# --- ROAD-46 Phase 3: §9 tool-first Finish + §5–§6 granular telemetry (skill text) ---
grep -qF '**Tool-first Finish (non-negotiable):**' "$SKILL" \
  || fail "SKILL must document Tool-first Finish (non-negotiable) for AskQuestion"
grep -qF 'call `AskQuestion` first' "$SKILL" \
  || fail "SKILL must require AskQuestion before git when tool available"
# ROAD-52: START may be spelled as log-gate.sh impl-start instead of a raw impl | START line.
if ! grep -qF 'impl | START | phase: k | domain:' "$SKILL"; then
  grep -qF 'log-gate.sh --ticket <ticket-folder> impl-start' "$SKILL" \
    || fail "SKILL must document impl START telemetry (log-gate.sh --ticket impl-start or legacy line)"
fi
grep -qF 'impl | DONE | phase: k | spec:' "$SKILL" \
  || fail "SKILL must document impl | DONE telemetry (multi-phase)"
grep -qF 'impl-review | GATE |' "$SKILL" \
  || fail "SKILL must document impl-review | GATE telemetry"

echo "OK: Task(do) / session / router doc checks passed"
