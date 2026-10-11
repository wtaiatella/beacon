#!/usr/bin/env bash
#
# Optional warnings-only scan for plan-segment keywords in run-pipeline skill
# and related files. Mirrors check-nested-task-docs.sh (always exit 0; CI non-blocking).
#
# Usage: ./scripts/tools/check-plan-segment-docs.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/agentic/skills/run-pipeline/SKILL.md"
ROUTER="$ROOT/agentic/adapters/cursor/rules/00-workspace-router.mdc"
PLAN_AGENT="$ROOT/agentic/agents/plan.md"

echo "── Plan segment doc signals (warnings-only) ──"

WARN=0

if [[ ! -f "$SKILL" ]]; then
  echo "WARN Missing $SKILL"
  exit 0
fi

if ! grep -qF 'PLAN_REVIEW_FEEDBACK' "$SKILL" 2>/dev/null; then
  echo "WARN agentic/skills/run-pipeline/SKILL.md -- expected PLAN_REVIEW_FEEDBACK (plan self-heal persistence)"
  WARN=1
fi

if ! grep -qF -- '--max-plan-iterations' "$SKILL" 2>/dev/null; then
  echo "WARN agentic/skills/run-pipeline/SKILL.md -- expected --max-plan-iterations (plan ↔ plan-reviewer cap)"
  WARN=1
fi

# REQUEST_MAIN: may appear in SKILL and/or router + plan agent (flat escalation contract).
if ! grep -qF 'REQUEST_MAIN' "$SKILL" 2>/dev/null; then
  if [[ -f "$ROUTER" ]] && grep -qF 'REQUEST_MAIN' "$ROUTER" 2>/dev/null; then
    :
  elif [[ -f "$PLAN_AGENT" ]] && grep -qF 'REQUEST_MAIN' "$PLAN_AGENT" 2>/dev/null; then
    :
  else
    echo "WARN Plan-segment escalation -- REQUEST_MAIN: not found in SKILL.md, 00-workspace-router.mdc, or plan.md"
    WARN=1
  fi
fi

if [[ "$WARN" -eq 0 ]]; then
  echo "OK Plan segment keywords present (PLAN_REVIEW_FEEDBACK, --max-plan-iterations, REQUEST_MAIN chain)"
fi
exit 0
