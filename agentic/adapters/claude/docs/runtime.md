# Claude Code runtime (adapter)

This workspace’s SDD framework is canonical under **`agentic/`**. Claude Code consumes a
**generated** mirror:

| Concept | Canonical | Installed to |
|---------|-----------|--------------|
| Always-on context | `agentic/adapters/claude/CLAUDE.md` | `CLAUDE.md` (repo root) |
| Agents | `agentic/agents/` | `.claude/agents/` |
| Skills | `agentic/skills/` | `.claude/skills/` |
| Commands | `agentic/commands/` | `.claude/commands/` |
| Hooks | `agentic/hooks/` + `adapters/claude/settings.json` | `.claude/hooks/` + `.claude/settings.json` |
| Adapter docs | `agentic/adapters/claude/docs/` | `docs/adapters/claude/` |

Install:

```bash
scripts/setup-agentic.sh claude
```

Project skills, agents, and commands are **not** in `agentic/`. Setup does not copy or link
them. The Cursor adapter may deactivate the managed Claude framework mirror (paths listed in
`.claude/.agentic-managed` only) to avoid duplicate slash entries.

## vs Cursor

| Concern | Claude | Cursor |
|---------|--------|--------|
| Always-on | root `CLAUDE.md` | `.cursor/rules/*.mdc` |
| Personas | plugin `beacon-sdd` (`/beacon-sdd:<name>`) | `.cursor/agents` |
| Skills | plugin `beacon-sdd` | `.cursor/skills` |
| Hooks config | `.claude/settings.json` | `.cursor/hooks.json` |
| Hook I/O | Claude Pre/PostToolUse | Cursor events (dual-protocol scripts) |

Shared orchestration law (flat Task, git/GitLab consent, ticket-folder `_state.json`) is the
same; only paths and hook wiring differ.
