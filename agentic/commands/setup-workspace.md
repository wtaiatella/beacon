---
description: "Interactive workspace tool registry. Probes MCP servers declared in .mcp.json, discovers workspace-specific context (Figma project, Confluence space, etc.) via AI-driven exploration, and writes docs/workspace-tools.md. Lists project skills and agents for the pre-plan wave and registers custom domain specialists (--specialist <name>). Read automatically by pre-plan-triage on every /run. No args = all servers; with name = that server only; --reset = wipe and restart."
argument-hint: "[server-name ... | --specialist <name> | --reset]"
---
Invoke the `setup-workspace` skill (`beacon-sdd:setup-workspace` with the Skill tool, or Read `${CLAUDE_PLUGIN_ROOT}/skills/setup-workspace/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
