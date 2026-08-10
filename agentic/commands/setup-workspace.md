---
description: "Interactive workspace tool registry. Probes MCP servers declared in .mcp.json, discovers workspace-specific context (Figma project, Confluence space, etc.) via AI-driven exploration, and writes docs/workspace-tools.md. Read automatically by pre-plan-triage on every /run. No args = all servers; with name = that server only; --reset = wipe and restart."
argument-hint: "[server-name ... | --reset]"
---
Load the `setup-workspace` skill (Read `.claude/skills/setup-workspace/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
