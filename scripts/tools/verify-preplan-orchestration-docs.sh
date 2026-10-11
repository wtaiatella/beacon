#!/usr/bin/env bash
# Blocking doc checks for /run pre-plan: flat orchestration, wave skips, merge+gate,
# merged brief handoff.
# Run from repo root: ./scripts/tools/verify-preplan-orchestration-docs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SKILL=".cursor/skills/run-pipeline/SKILL.md"
ROUTER=".cursor/rules/00-workspace-router.mdc"
REF="docs/run-pipeline-reference.md"

echo "verify-preplan-orchestration-docs: repo root=$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test -f "$SKILL" || fail "missing $SKILL"
test -f "$ROUTER" || fail "missing $ROUTER"
test -f "$REF" || fail "missing $REF"

# --- run-pipeline SKILL: forbid plan-nested Task(mcp-*) for /run pre-plan ---
grep -q 'nested' "$SKILL" || fail "SKILL must discuss nested vs flat pre-plan MCP"
grep -q 'Task(plan)' "$SKILL" || fail "SKILL must mention Task(plan) in pre-plan context"
grep -qE '`Task\(mcp-\*\)`|Task\(mcp-' "$SKILL" || fail "SKILL must mention Task(mcp-*) or Task(mcp-…) for pre-plan"
grep -qE 'not nested inside|must not.*nest|/plan` must not' "$SKILL" \
  || fail "SKILL must forbid nesting Task(mcp-*) inside Task(plan) for /run pre-plan"

# --- Wave 1 omitted when triage lists none of the enterprise sources ---
grep -q 'Skip Wave 1' "$SKILL" || fail "SKILL must document Skip Wave 1 when wave1 empty"
grep -q 'neither' "$SKILL" || fail "SKILL must state Wave 1 skip when triage lists none of jira/confluence/glean"
grep -qE 'jira|confluence|glean' "$SKILL" || fail "SKILL must name jira/confluence/glean for Wave 1 triage"

# --- merge + gate before Wave 2 ---
grep -q 'merge + gate' "$SKILL" || fail "SKILL must document merge + gate before Wave 2"

# --- merged-brief.md and summarized Pre-plan context for Task(plan) ---
grep -q 'merged-brief.md' "$SKILL" || fail "SKILL must reference pre-plan/merged-brief.md"
grep -qE 'summar' "$SKILL" || fail "SKILL must require summarized (not raw) Pre-plan context for Task(plan)"

# --- workspace router: flat orchestration for pre-plan MCP ---
grep -q 'Flat orchestration' "$ROUTER" || fail "router must document Flat orchestration"
grep -q 'Pre-plan MCP' "$ROUTER" || fail "router must document Pre-plan MCP specialists / flat gather"

# --- run-pipeline-reference: nested vs flat section ---
grep -q 'Nested vs flat' "$REF" || fail "docs/run-pipeline-reference.md must contain Nested vs flat"

echo "OK: pre-plan orchestration doc checks passed"
