# Claude Code adapter

## Install targets (via `scripts/setup-agentic.sh claude`)

| Canonical | Installed to |
|-----------|----------------|
| `agentic/adapters/claude/CLAUDE.md` | `CLAUDE.md` (repo root, **generated**) |
| `agentic/{agents,skills,commands,hooks}` | user plugin `beacon-sdd` (`~/.claude/plugins/marketplaces/beacon-sdd-local/beacon-sdd`) |
| `adapters/claude/settings.json` | plugin `hooks/hooks.json` (`${CLAUDE_PLUGIN_ROOT}`) |
| `adapters/claude/docs/` | `docs/adapters/claude/` |

Managed framework paths are recorded in `.claude/.agentic-managed`. Prune only touches that list.
Setup does not copy or link project skills, agents, or commands.

## Always-on context

Edit **`agentic/adapters/claude/CLAUDE.md`**, then re-run setup. Do not edit the generated root `CLAUDE.md`.

## Hooks

Scripts under `agentic/hooks/` are dual-protocol (Claude Code + Cursor). Claude wiring is
event names + matchers in `settings.json`; Cursor wiring is `adapters/cursor/hooks.json`.
Shared payload/response normalization lives in `hooks/lib/hook-protocol.js`.

## Project skills, agents, and commands

Anything **not** installed from `agentic/` is left untouched. Keep it in the project;
do not add it under `agentic/`. Setup does not symlink it into an IDE runtime.
