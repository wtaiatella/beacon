---
description: "Multi-repo git-sync with safety backup branch. No args → if this conversation has exactly one ticket, rebase the repo(s) that ticket changed (fallback: ticket _state.json repo/branch); otherwise rebase every child repo. Repo name → that repo's current branch. Repo + ticket key (e.g. engine BG-11320) → checkout/create the ticket branch from origin, then rebase. After a clean rebase, push --force-with-lease (or -u if no upstream). No MR creation, no Jira transition. Standalone — not wired into /run."
argument-hint: "[repo-name] [ticket-key]"
---
Load the `rebase` skill (Read `.claude/skills/rebase/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
