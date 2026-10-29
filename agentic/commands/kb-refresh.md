---
description: "Incremental multi-repo knowledge refresh: git pull each child repo, classify what changed, refresh only affected knowledge/<repo>/ sections, then hand off to kb-concentrator. Standalone — not wired into /run."
argument-hint: "[repo ...]"
---
Invoke the `kb-refresh` skill (`beacon-sdd:kb-refresh` with the Skill tool, or Read `${CLAUDE_PLUGIN_ROOT}/skills/kb-refresh/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
