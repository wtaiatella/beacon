---
description: "Multi-repo git-sync with safety backup branch. No args → rebase every child repo. With repo name → rebase only that repo. After a clean rebase, push --force-with-lease (or -u if no upstream). No MR creation, no Jira transition. Standalone — not wired into /run."
argument-hint: "[repo-name]"
---
Load the `rebase` skill (Read `.claude/skills/rebase/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
