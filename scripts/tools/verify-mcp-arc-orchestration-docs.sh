#!/usr/bin/env bash
# Doc consistency checks for MCP ARC pre-plan orchestration.
# Exit 0 when positive assertions hold and no stale "no ... Task(mcp-arc)" policy lines appear.
# Run from repo root: ./scripts/tools/verify-mcp-arc-orchestration-docs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "verify-mcp-arc-orchestration-docs: repo root=$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# --- Positive: pre-plan Task(mcp-arc) alongside other MCP specialists ---
grep -qE 'Task\(mcp-glean\)|Task\(mcp-confluence\)|Task\(mcp-jira\)|Task\(mcp-gitlab\)|Task\(mcp-arc\)' .cursor/rules/00-workspace-router.mdc \
  || fail "router must list parallel pre-plan Task(mcp-glean|...|mcp-arc)"
grep -q 'Task(mcp-arc)' .cursor/skills/run-pipeline/SKILL.md \
  || fail "run-pipeline SKILL must mention Task(mcp-arc)"

# --- Positive: self-heal trio (same escape hatches as router + skill) ---
grep -q '`/fix`' .cursor/rules/00-workspace-router.mdc \
  && grep -q '`/do`' .cursor/rules/00-workspace-router.mdc \
  && grep -q '`/run --resume`' .cursor/rules/00-workspace-router.mdc \
  || fail "00-workspace-router must list /fix, /do, /run --resume in self-heal"
grep -q 'Self-heal' .cursor/skills/run-pipeline/SKILL.md \
  && grep -q '`/fix`' .cursor/skills/run-pipeline/SKILL.md \
  && grep -q '`/do`' .cursor/skills/run-pipeline/SKILL.md \
  && grep -q '`/run --resume`' .cursor/skills/run-pipeline/SKILL.md \
  || fail "run-pipeline SKILL Error handling must list self-heal trio with /fix, /do, /run --resume"

# --- Positive: Finish git push only after explicit Yes (both policy files) ---
grep -q 'git push' .cursor/rules/git-gitlab-mutations.mdc \
  || fail "git-gitlab-mutations must document Finish git push policy"
grep -qE 'AskQuestion|explicit.*Yes|Yes, I want to push' .cursor/rules/git-gitlab-mutations.mdc \
  || fail "git-gitlab-mutations must tie push to AskQuestion or explicit Yes"
grep -q '§ 9' .cursor/skills/run-pipeline/SKILL.md \
  || fail "run-pipeline SKILL must reference Finish (§ 9)"
grep -q 'git push' .cursor/skills/run-pipeline/SKILL.md \
  || fail "run-pipeline SKILL § Finish must mention git push"

# --- Negative: stale denial of pre-plan Task(mcp-arc) (allow "do not nest", changelog, etc.) ---
# Match isolated word "no" near Task(mcp-arc); exclude nesting guidance and lane (B) caveats.
STALE="$(
  git grep -nE '\bno\b.*Task\(mcp-arc\)|Task\(mcp-arc\).*\bno\b' -- \
    '*.md' '*.mdc' '.cursor/' 2>/dev/null \
    | grep -vE 'nest|nested|substitute|replace lane|CHANGELOG|changelog' \
    || true
)"
if [[ -n "${STALE}" ]]; then
  echo "Found possible stale 'no ... Task(mcp-arc)' wording (review; nesting lines should use nest|nested):" >&2
  echo "${STALE}" >&2
  fail "remove or rephrase stale pre-plan denial; nesting guidance is OK"
fi

echo "OK: MCP ARC pre-plan orchestration doc checks passed"
