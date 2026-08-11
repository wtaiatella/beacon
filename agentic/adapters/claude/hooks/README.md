# Claude Code — adapter hooks

Shared hooks install from `agentic/hooks/` into `.claude/hooks/`.

**Action/tool audit is intentionally not installed for Claude yet.**

When a Claude-specific audit exists, add it here (e.g. `tool-audit.sh`) and wire it in
`agentic/adapters/claude/settings.json`. Do **not** reuse
`agentic/adapters/cursor/hooks/tool-audit.sh` — Cursor and Claude need independent strategies.

Planned outputs (when implemented):

- `docs/local/audit-claude/<session>/` (future; mirror Cursor chat→turns→actions layout)
- Legacy TSV names (`action-audit-claude.tsv`) are retired for new work
