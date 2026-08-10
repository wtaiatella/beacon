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

Project overlays (`bcs-*`) are **not** in `agentic/`; they live under `.claude/` and are
tracked separately. The Cursor adapter may deactivate the managed Claude framework mirror
to avoid duplicate slash entries — overlays are kept.

## vs Cursor

| Concern | Claude | Cursor |
|---------|--------|--------|
| Always-on | root `CLAUDE.md` | `.cursor/rules/*.mdc` |
| Personas | `.claude/agents` + `.claude/commands` | `.cursor/agents` (+ skills in `.agents/skills`) |
| Skills | `.claude/skills` | `.agents/skills` |
| Hooks config | `.claude/settings.json` | `.cursor/hooks.json` |
| Hook I/O | Claude Pre/PostToolUse | Cursor events (dual-protocol scripts) |

Shared orchestration law (flat Task, git/GitLab consent, ticket-folder `_state.json`) is the
same; only paths and hook wiring differ.
