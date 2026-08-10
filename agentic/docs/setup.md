# Setup — Agentic Workspace (`setup-agentic.sh`)

Canonical setup guide. Installed tooling comes from **`agentic/`**; IDE runtimes are generated.

## Prerequisites

- **Node.js ≥ 18** — hook scripts (`node` JSON helpers)
- **git ≥ 2.x**
- **Claude Code** and/or **Cursor** (install the IDE(s) you use)

## Install a runtime

```bash
# from repo root
scripts/setup-agentic.sh claude        # → .claude/ + root CLAUDE.md + docs/adapters/claude/
scripts/setup-agentic.sh cursor        # → .cursor/ + .agents/skills/ + docs/adapters/cursor/
scripts/setup-agentic.sh all           # claude + cursor (+ antigravity stub)
scripts/setup-agentic.sh cursor --dry-run
scripts/setup-agentic.sh cursor --keep-claude   # dual-IDE: keep Claude framework mirror
```

### What gets generated (gitignored)

| Runtime | Outputs |
|---------|---------|
| Claude | `.claude/{agents,skills,commands,hooks,settings.json}`, root `CLAUDE.md` |
| Cursor | `.cursor/{agents,hooks,hooks.json,rules}`, `.agents/skills/` |
| Docs | `docs/adapters/{claude,cursor}/` |

### What stays tracked

- `agentic/` — SDD source of truth
- `.claude/**/bcs-*` — project overlays (not part of SDD)
- `.mcp.json` — shared MCP baseline (optional; not generated yet)
- `docs/` — shared product/process docs (see `agentic/docs/README.md`)

## After install

**Claude Code:** open the repo; confirm root `CLAUDE.md` exists and `/prd` (etc.) resolve via `.claude/commands` → Task.

**Cursor:** Settings → Rules (always-apply workspace rules); confirm agents under `.cursor/agents/` and skills under `.agents/skills/`; Hooks from `.cursor/hooks.json`.

## Local action/tool audit (Claude vs Cursor studies)

The adapters install a post-tool hook that appends high-level action rows at:

```text
docs/local/action-audit.tsv
```

This file is outside `docs/specs/` (safe when specs are symlinked between workspaces) and is gitignored. Use it to compare action duration, status, and best-effort token totals between a Claude workspace (for example BCS) and a Cursor workspace (for example BCS1):

```bash
scripts/tools/tool-audit-summary.sh docs/local/action-audit.tsv
```

For per-tool detail, enable detail mode before running the IDE/CLI:

```bash
TOOL_AUDIT_DETAIL=1 claude
# or
export TOOL_AUDIT_DETAIL=1
```

For Cursor launched from the GUI, create the local marker instead:

```bash
mkdir -p docs/local && touch docs/local/TOOL_AUDIT_DETAIL
```

Detail mode writes `docs/local/tool-audit.tsv` with an `action` column so each row can be grouped back to the invoking task/subagent/command when it can be inferred.

After running the same ticket in both workspaces, copy each TSV into one analysis workspace under different names, then summarize or diff them.

## Dual-IDE note

Default `cursor` install **deactivates** the managed Claude framework mirror under `.claude/` (overlays `bcs-*` remain) so `/` is not duplicated. Use `--keep-claude` or `all` if you need both mirrors populated.

## Edit workflow

1. Change files under `agentic/` (or `agentic/adapters/...`)
2. Re-run `scripts/setup-agentic.sh <claude|cursor|all>`
3. Do **not** hand-edit generated trees (they will be overwritten)
