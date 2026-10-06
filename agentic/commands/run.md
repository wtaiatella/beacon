---
description: Orchestrate the full SDD+GSD pipeline (PRD → Spectech → Tasks → implement → review → QA → summary) via the run-pipeline skill.
argument-hint: "<ticket-folder-or-jira-key> [idea] [flags]"
---

The user invoked `/run`. You are the ORCHESTRATOR in this main conversation loop — there is NO `run` subagent.

1. **Read** `.claude/skills/run-pipeline/SKILL.md` (use the Read tool) and follow it as authoritative for the full workflow. Do not rely on memory alone on the first turn of a new `/run`.
2. Treat `$ARGUMENTS` as `<ticket-folder-or-jira-key> [idea] [flags]` (flags like `--review`, `--skip`, `--branch`, `--resume`, `--confidence N`, `--max-iterations N`, `--manual`, `--model-strategy`, `--budget`). The primary argument is a ticket-folder path (`docs/specs/{YYYY-MM-DD}-ticket-{slug}/`) or a Jira key that resolves to/creates one — never a single `spec.md` path.
3. Delegate each step with the Task tool: `Task(prd)`→`Task(spectech)`→`Task(tasks)` (the required front end — no `Task(plan)`), `Task(dev|sre|data)`, reviewers, `Task(qa)`, `Task(summary)`, `Task(scrum)`, and pre-plan `Task(pre-plan-triage)` + `Task(mcp-*)` waves — ONLY from this main session (flat orchestration; personas never nest Task).
4. Enforce branch consent, gates, and confidence thresholds per the skill. NEVER auto-commit/push/MR without explicit user consent (see the Git/GitLab guardrails in CLAUDE.md and the skill's §9 Finish).
5. Track gates in session memory (`scripts/tools/session-memory.sh`).
