# Antigravity adapter (stub)

## Install targets (via `scripts/setup-agentic.sh antigravity`)

| Canonical | Installed to |
|-----------|----------------|
| `agentic/skills/` | `.agent/skills/` (copy) |
| `agentic/commands/` | `.agent/workflows/` (markdown proxies; rename later to Antigravity workflow format) |
| `agentic/agents/` | *(not auto-mapped)* — Antigravity uses `invoke_subagent`, not Claude `Task` |

Managed paths are recorded in `.agent/.agentic-managed`.

## Status

Skeleton only. Next iterations should:

1. Rewrite command proxies to `invoke_subagent` language
2. Map hooks to Antigravity `PreToolUse` / `PostToolUse` / etc.
3. Decide whether agents become Antigravity skills or defined subagents
