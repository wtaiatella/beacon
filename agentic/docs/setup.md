# Setup — Agentic Workspace (`setup-agentic.sh`)

Canonical setup guide. Installed tooling comes from **`agentic/`**; IDE runtimes are generated.

## Prerequisites

- **Node.js ≥ 18** — hook scripts (`node` JSON helpers)
- **git ≥ 2.x**
- **Claude Code** and/or **Cursor** (install the IDE(s) you use)

## Install a runtime

```bash
# from repo root
scripts/setup-agentic.sh claude        # → user plugin beacon-sdd + root CLAUDE.md
scripts/setup-agentic.sh cursor        # → .cursor/ (agents, hooks, rules, skills)
scripts/setup-agentic.sh all           # claude + cursor (+ antigravity stub)
scripts/setup-agentic.sh cursor --dry-run
scripts/setup-agentic.sh cursor --keep-claude   # dual-IDE: keep Claude framework mirror
```

### What gets generated (gitignored)

| Runtime | Outputs |
|---------|---------|
| Claude | user plugin `beacon-sdd` (`/beacon-sdd:<name>`), root `CLAUDE.md`. Project `.claude/` keeps overlays only (any name — no naming-prefix convention) |
| Cursor | `.cursor/{agents,hooks,hooks.json,rules,skills}` — framework content under a `beacon/` subfolder in each; overlays linked flat outside it |
| Docs | `docs/adapters/{claude,cursor}/` |

### What stays tracked

- `agentic/` — SDD source of truth
- `.agents/{agents,commands,skills}/` and their `.claude/**` symlinks — project overlays (any name; not part of SDD)
- `.mcp.json` — shared MCP baseline (optional; not generated yet)
- `docs/` — shared product/process docs (see `agentic/docs/README.md`)

## After install

**Claude Code:** open the repo; confirm root `CLAUDE.md` exists and `/beacon-sdd:prd` (etc.) resolve from the user plugin. Third-party import in Cursor stays off, or those commands also appear in Cursor.

**Cursor:** Settings → Rules (always-apply workspace rules); confirm agents under `.cursor/agents/beacon/` and skills under `.cursor/skills/beacon/` (anything outside `beacon/` in those directories is not part of the SDD framework); Hooks from `.cursor/hooks.json`. Leave **Include Third-Party Plugins, Skills, and Other Configs** off.

## Local action audit (per IDE)

Action/tool audit is **IDE-specific** — scripts and outputs are not shared.

| IDE | Hook source | Output |
|---|---|---|
| **Cursor** | `agentic/adapters/cursor/hooks/tool-audit.sh` | `docs/local/audit-cursor/<session>/` (chat → turns → actions) |
| **Claude** | not installed yet (`adapters/claude/hooks/README.md`) | `docs/local/audit-claude/` (future) |

Shared hooks under `agentic/hooks/` (shell gate, session-init, …) install for every IDE; audit overlays only from `agentic/adapters/<ide>/hooks/`.

### Cursor

Chat-centric layout under `docs/local/audit-cursor/<session_id>/`:

| File | Meaning |
|---|---|
| `summary.json` | Chat totals (`tokens_api_*` after sync; `tokens_est_*` fallback) |
| `turns.jsonl` | One record per user question |
| `actions.jsonl` | Task/subagent work nested under a turn |
| `billing.json` | Cursor Usage API events for this chat (+ child subagents) |

`tokens_est_*` = transcript `chars/4` (fallback). Real spend/tokens: run usage sync.

| Event | Role |
|---|---|
| `beforeSubmitPrompt` | Open a turn for the user question |
| `postToolUse` / `postToolUseFailure` | Turn tool counters + action progress |
| `subagentStop` | Finish an action (re-estimate from full subagent transcript) |
| `stop` | Close the current turn; refresh chat totals from parent transcript |

```bash
scripts/tools/tool-audit-summary.sh --ide cursor
scripts/tools/tool-audit-summary.sh --ide cursor <session-id>
scripts/tools/tool-audit-backfill.sh --ide cursor
scripts/tools/cursor-usage-sync.sh [--days 31] [session-id]
```

**Billing sync auth:** `cursor-usage-sync.sh` reads the Cursor session JWT from the local
`state.vscdb` **once per run into memory only** (same approach as the Cursor Usage extension).
It never writes the token under `docs/local/`. Cached artifacts are events only
(`docs/local/cursor-usage-cache/`).

Legacy `docs/local/action-audit-cursor.tsv` is no longer written; summary still reads it if no `audit-cursor/` chats exist.
### Claude

No audit hook until a Claude-specific strategy is added under `agentic/adapters/claude/hooks/` and wired in `settings.json`.

## Dual-IDE note

Default `cursor` install **deactivates** the managed Claude framework mirror under `.claude/` (overlays remain, any name) so `/` is not duplicated. Use `--keep-claude` or `all` if you need both mirrors populated.

## Edit workflow

1. Change files under `agentic/` (or `agentic/adapters/...`)
2. Re-run `scripts/setup-agentic.sh <claude|cursor|all>`
3. Do **not** hand-edit generated trees (they will be overwritten)
