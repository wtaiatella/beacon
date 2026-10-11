#!/usr/bin/env bash
# Blocking doc checks for /run pre-plan: flat orchestration, the enterprise
# wave's empty-by-default skip, merge+gate before Task(prd), merged brief
# handoff. Terminology matches the current generic domain-specialist +
# gated-enterprise-wave design (no more Task(plan) or a separate "Wave 1"
# enterprise breadth pass — see agentic/agents/pre-plan-triage.md).
# Run from repo root: ./scripts/tools/verify-preplan-orchestration-docs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SKILL="agentic/skills/run-pipeline/SKILL.md"
ROUTER="agentic/adapters/cursor/rules/00-workspace-router.mdc"
AGENTS_MD="agentic/AGENTS.md"
REF="docs/run-pipeline-reference.md"

echo "verify-preplan-orchestration-docs: repo root=$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test -f "$SKILL" || fail "missing $SKILL"
test -f "$ROUTER" || fail "missing $ROUTER"
test -f "$AGENTS_MD" || fail "missing $AGENTS_MD"
test -f "$REF" || fail "missing $REF"

# --- run-pipeline SKILL: forbid plan-nested Task(mcp-*) for /run pre-plan ---
grep -q 'nested' "$SKILL" || fail "SKILL must discuss nested vs flat pre-plan MCP"
grep -q 'Task(prd)' "$SKILL" || fail "SKILL must mention Task(prd) in pre-plan context"
grep -qE '`Task\(mcp-\*\)`|Task\(mcp-' "$SKILL" || fail "SKILL must mention Task(mcp-*) or Task(mcp-…) for pre-plan"
grep -qE 'not nested inside|must not.*nest|/prd` must not' "$SKILL" \
  || fail "SKILL must forbid nesting Task(mcp-*) inside Task(prd) for /run pre-plan"

# --- Enterprise wave omitted when triage lists none of jira/confluence/glean ---
grep -qE 'empty is the common case|wave2_sources.*empty' "$SKILL" \
  || fail "SKILL must document that the enterprise wave is skipped when wave2_sources is empty"
grep -qE 'jira|confluence|glean' "$SKILL" || fail "SKILL must name jira/confluence/glean for the enterprise wave"

# --- merge + gate before Task(prd) ---
grep -qE 'merge\s*\+\s*gate' "$SKILL" || fail "SKILL must document merge + gate before Task(prd)"

# --- merged-brief.md and summarized Pre-plan context for Task(prd) ---
grep -q 'merged-brief.md' "$SKILL" || fail "SKILL must reference pre-plan/merged-brief.md"
grep -qE 'summar' "$SKILL" || fail "SKILL must require summarized (not raw) Pre-plan context for Task(prd)"

# --- workspace router: flat orchestration lives here; pre-plan MCP detail lives in AGENTS.md (not duplicated) ---
grep -q 'Flat orchestration' "$ROUTER" || fail "router must document Flat orchestration"
grep -qE 'Pre-plan domain specialists|mcp-confluence.*mcp-gitlab.*mcp-jira|REQUEST_MAIN' "$AGENTS_MD" \
  || fail "AGENTS.md must document the pre-plan wave / enterprise MCP specialists (router defers here by design)"

# --- run-pipeline-reference: nested vs flat section ---
grep -q 'Nested vs flat' "$REF" || fail "docs/run-pipeline-reference.md must contain Nested vs flat"

echo "OK: pre-plan orchestration doc checks passed"
