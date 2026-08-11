---
description: "Morning triage of docs/specs ticket folders: analysis/implement status, new Jira comments, all GitLab MRs (multi-repo), pipelines, auto-rebase when behind development, auto-move merged tickets to completed/, write daily-status markdown, optionally /loop-watch running pipelines."
argument-hint: "[--dry-run] [--no-watch] [--ticket KEY|folder] [--watch-interval Nm] [--watch-timeout Nm]"
---
You are the main-session orchestrator for daily ticket triage — there is no dedicated subagent.

1. **Read** `.claude/skills/bcs-daily-ticket-triage/SKILL.md` and follow it as authoritative.
2. Treat `$ARGUMENTS` as optional flags (`--dry-run`, `--no-watch`, `--ticket`, `--watch-interval`, `--watch-timeout`).
3. Auto-rebase and auto-move to `docs/specs/completed/` per the skill (unless `--dry-run`). Never auto-push, never auto-merge MRs, never transition Jira.
4. For multi-repo tickets, check **every** involved repo's MR and pipeline before declaring review/merge/completed.
5. Write `docs/specs/daily-status-YYYY-MM-DD.md` and start the pipeline watcher when needed.

$ARGUMENTS
