---
description: "Incremental multi-repo knowledge refresh: git pull each child repo, classify what changed, refresh only affected knowledge/<repo>/ sections, then hand off to kb-concentrator. Standalone — not wired into /run."
argument-hint: "[repo ...]"
---

Treat `$ARGUMENTS` as an optional list of child-repo names to scope the refresh (empty = all child repos).

## Workflow

1. **Read** `.claude/skills/kb-refresh/SKILL.md` (use the Read tool) and follow it as authoritative — this is a thin utility command, not a persona subagent (mirrors `/clone`'s shape).
2. For each targeted repo (or every child repo if `$ARGUMENTS` is empty), follow the skill's workflow: dirty-tree guard → checkout main/default → `git pull --ff-only` → classify the diff → refresh `knowledge/<repo>/` only if changed.
3. If any repo's changes affect the system-level, cross-repo view, follow up with `/kb-concentrator`.
4. Report a summary: which repos were skipped (dirty or unchanged) vs refreshed, and what changed in each.

## Guardrails

- Non-destructive: skip (don't stash/reset) dirty repos, with a clear warning.
- Only refresh repos that actually changed.
