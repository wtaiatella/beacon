# Claude Code adapter

## Install targets (via `scripts/setup-agentic.sh claude`)

| Canonical | Installed to |
|-----------|----------------|
| `agentic/adapters/claude/CLAUDE.md` | `CLAUDE.md` (repo root, **generated**) |
| `agentic/agents/` | `.claude/agents/` |
| `agentic/skills/` | `.claude/skills/` |
| `agentic/commands/` | `.claude/commands/` |
| `agentic/hooks/` | `.claude/hooks/` |
| `adapters/claude/settings.json` | `.claude/settings.json` |
| `adapters/claude/docs/` | `docs/adapters/claude/` |

Managed framework paths are recorded in `.claude/.agentic-managed`. Prune only touches that list.
Project overlays (`bcs-*`) under `.claude/` are tracked in git and never pruned by setup.

## Always-on context

Edit **`agentic/adapters/claude/CLAUDE.md`**, then re-run setup. Do not edit the generated root `CLAUDE.md`.

## Hooks

Scripts under `agentic/hooks/` are dual-protocol (Claude Code + Cursor). Claude wiring is
event names + matchers in `settings.json`; Cursor wiring is `adapters/cursor/hooks.json`.
Shared payload/response normalization lives in `hooks/lib/hook-protocol.js`.

## Project overlays

Any agents/commands/skills **not** installed from `agentic/` (and therefore absent from
`.agentic-managed`) are left untouched by setup. Keep project overlays in the runtime dir;
do not add them under `agentic/`.
