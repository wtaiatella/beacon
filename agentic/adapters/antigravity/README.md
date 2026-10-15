# Antigravity Adapter (Global Plugin)

## Install targets (via `scripts/setup-agentic.sh antigravity`)

| Canonical | Installed to |
|-----------|----------------|
| `agentic/adapters/antigravity/plugin.json` | `~/.gemini/config/plugins/beacon-sdd/plugin.json` |
| `agentic/adapters/antigravity/hooks.json` | `~/.gemini/config/plugins/beacon-sdd/hooks.json` |
| `agentic/adapters/antigravity/rules/` | `~/.gemini/config/plugins/beacon-sdd/rules/` |
| `agentic/skills/` + persona skills | `~/.gemini/config/plugins/beacon-sdd/skills/` |
| `agentic/hooks/` | `~/.gemini/config/plugins/beacon-sdd/hooks/` |
| `agentic/AGENTS.md` | `AGENTS.md` (repo root, **generated**) |
| `agentic/adapters/antigravity/docs/` | `docs/adapters/antigravity/` |

Managed framework paths are recorded in `.agents/.agentic-managed`.

## Architectural Mapping

1. **Global Plugin:** Installed in `~/.gemini/config/plugins/beacon-sdd/`. Discovered automatically by Antigravity IDE and Antigravity 2.0 without per-repo configuration.
2. **Skills-as-Personas:** Personas (`dev`, `qa`, `scrum`, `prd`, etc.) and pipeline orchestrators (`run`, `run-pipeline`) are mapped to Antigravity skills with Progressive Disclosure.
3. **Tri-protocol Hooks:** Lifecycle hooks in `hooks/` use `hooks/lib/hook-protocol.js` which detects Antigravity JSON payloads on stdin and responds with `{ "decision": "allow" | "deny" }`.
4. **Native Tool Mapping:** Abstract tool names are routed to Antigravity native tools (`run_command`, `view_file`, `write_to_file`, `replace_file_content`, `grep_search`, `list_dir`).

## Setup

```bash
scripts/setup-agentic.sh antigravity
```
