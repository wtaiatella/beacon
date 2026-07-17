---
description: "Interactive workspace tool registry. Probes MCP servers declared in .mcp.json, discovers workspace-specific context (Figma project, Confluence space, etc.) via AI-driven exploration, and writes docs/workspace-tools.md. Read automatically by pre-plan-triage on every /run. No args = all servers; with name = that server only; --reset = wipe and restart."
argument-hint: "[server-name ... | --reset]"
---

Load the `setup-workspace` skill and follow its instructions exactly. Treat `$ARGUMENTS` as
the input described in the skill's **Trigger & Input** section.

The skill runs in the **main session** (no subagent delegation) because it requires interactive
back-and-forth with the user during the discovery phase — subagents cannot hold mid-task
conversations.

After completing the skill workflow, confirm to the user that `docs/workspace-tools.md` has
been updated and remind them to re-run `/setup-workspace <name>` when a tool's config changes.
