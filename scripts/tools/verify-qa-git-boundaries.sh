#!/usr/bin/env bash
# Blocking doc checks for: QA boundaries, § 7.1 scrum authority, nested Task bans,
# Finish Git/MR safety. Modeled after verify-preplan-orchestration-docs.sh.
# Run from repo root: ./scripts/tools/verify-qa-git-boundaries.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SKILL="agentic/skills/run-pipeline/SKILL.md"
QA_AGENT="agentic/agents/qa.md"
SUMMARY_AGENT="agentic/agents/summary.md"
RULE_GL="agentic/adapters/cursor/rules/git-gitlab-mutations.mdc"

echo "verify-qa-git-boundaries: repo root=$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test -f "$SKILL" || fail "missing $SKILL"
test -f "$QA_AGENT" || fail "missing $QA_AGENT"
test -f "$SUMMARY_AGENT" || fail "missing $SUMMARY_AGENT"
test -f "$RULE_GL" || fail "missing $RULE_GL"

# --- run-pipeline SKILL: § 7.1 post-QA scrum; orchestrator does not apply QA proposals until § 7.1 ---
grep -qE '§[[:space:]]*7\.1|7\.1.*Task\(scrum\)|Final `Task\(scrum\).*post-QA' "$SKILL" \
  || fail "SKILL must document § 7.1 post-QA Task(scrum)"
grep -qE 'orchestrator must not|must not apply those proposals|Proposed spec updates' "$SKILL" \
  || fail "SKILL must state orchestrator withholding of QA proposals"
grep -qE 'until[[:space:]]+\*\*§[[:space:]]*7\.1\*\*|until[[:space:]]+§[[:space:]]*7\.1|§[[:space:]]*7\.1.*PROCEED' "$SKILL" \
  || fail "SKILL must tie spec patch application to § 7.1 / PROCEED"

# --- SKILL: forbid nested Task(spec-validator) / Task(security-scanner) from Task(qa) ---
grep -q 'Task(spec-validator)' "$SKILL" || fail "SKILL must mention Task(spec-validator)"
grep -q 'Task(security-scanner)' "$SKILL" || fail "SKILL must mention Task(security-scanner)"
grep -q 'Task(qa)' "$SKILL" || fail "SKILL must mention Task(qa)"
# Roster / Parallelism: "nested" + both Task names + anchoring to Task(qa) ("from inside" or "nested from")
grep -qE 'nested.*Task\(spec-validator\)|Task\(spec-validator\).*/.*Task\(security-scanner\)' "$SKILL" \
  || fail "SKILL must link nested ban to Task(spec-validator) / Task(security-scanner)"
grep -qE 'from inside|nested from' "$SKILL" || fail "SKILL must anchor nested Task ban to Task(qa) (from inside / nested from)"

# --- SKILL § 9 / Finish: no mutating GitLab API / glab mr create ---
grep -qE 'glab mr create|mutating GitLab|Never.*invoke mutating' "$SKILL" \
  || fail "SKILL § 9 / Finish must forbid glab mr create / mutating GitLab APIs"
grep -qE 'Post-pipeline shipping|§[[:space:]]*9|Finish' "$SKILL" \
  || fail "SKILL must reference § 9 or Finish shipping prompts"

# --- qa.md: no Task(...) on other personas; no nested Task(security-scanner) chain from QA ---
grep -qF 'Task(...)' "$QA_AGENT" || fail "qa.md must mention Task(...) delegation boundary"
grep -qE 'Do not[^[:cntrl:]]*invoke|do not[^[:cntrl:]]*invoke' "$QA_AGENT" \
  || fail "qa.md must forbid invoking Task(...) on other personas"
grep -q 'personas' "$QA_AGENT" || fail "qa.md must name other personas in Task boundary"
grep -q 'Task(security-scanner)' "$QA_AGENT" || fail "qa.md must mention Task(security-scanner)"
grep -qE 'nested|spawned from inside|not.*nested' "$QA_AGENT" \
  || fail "qa.md must state nested Task(security-scanner)/validator policy"

# --- summary.md: orchestrated § 8 minimal bundle (no raw transcript/diff dumps in orchestrator prompt) ---
grep -qE 'minimal delegation bundle|§[[:space:]]*8' "$SUMMARY_AGENT" \
  || fail "summary.md must document minimal delegation bundle / § 8 slicing"

# --- git-gitlab-mutations.mdc: push after explicit Yes; MR user-run ---
grep -qE 'explicit[[:space:]]+(user[[:space:]]+)?\*\*Yes\*\*|explicit[[:space:]]+(user[[:space:]]+)?Yes' "$RULE_GL" \
  || fail "rule must require explicit Yes for push"
grep -qE 'user-run|user to run|commands themselves' "$RULE_GL" \
  || fail "rule must state MR / mutating GitLab as user-run"

echo "OK: QA / Git / Finish boundary doc checks passed"
