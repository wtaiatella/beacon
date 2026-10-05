# Cursor adapter

## Install targets (via `scripts/setup-agentic.sh cursor`)

| Canonical | Installed to | Why |
|-----------|----------------|-----|
| `agentic/agents/` | `.cursor/agents/` | Cursor subagent discovery (persona / Task entrypoints) |
| `agentic/skills/` | `.cursor/skills/` | Cursor skills path (`/`), kept inside `.cursor/` |
| `agentic/commands/` | *(not installed)* | Avoid duplicate `/` next to agents; Claude-only thin proxies |
| `agentic/hooks/` | `.cursor/hooks/` | Shared dual-protocol scripts (+ `lib/hook-protocol.js`) |
| `adapters/cursor/hooks/*` | `.cursor/hooks/` (overlay) | Cursor-only hooks (e.g. `tool-audit.sh`) |
| `adapters/cursor/hooks.json` | `.cursor/hooks.json` | Cursor hook events |
| `adapters/cursor/rules/*.mdc` | `.cursor/rules/` | Always-on context (**CLAUDE.md equivalent**) |
| `adapters/cursor/docs/` | `docs/adapters/cursor/` | Cursor platform reference (generated) |

Manifests: `.cursor/.agentic-managed` and `.agents/.agentic-managed`.
Generated runtimes and `docs/adapters/` are **gitignored** — only `agentic/` (+ `bcs-*` overlays) is source.

## Always-on context (CLAUDE.md → Cursor rules)

Claude Code loads root `CLAUDE.md`. Cursor loads project rules under `.cursor/rules/`.
This adapter ships three always-apply rules (source under `adapters/cursor/rules/`):

| Rule | Role |
|------|------|
| `00-workspace-router.mdc` | Identity, ticket folder, personas, flat orchestration, multi-repo |
| `run-pipeline-trigger.mdc` | `/run` → read/follow `run-pipeline` skill |
| `git-gitlab-mutations.mdc` | No silent commit/push/MR; `/rebase` may `--force-with-lease` after a clean rebase |

Edit the sources under `agentic/adapters/cursor/rules/`, then re-run `scripts/setup-agentic.sh cursor`.
Keep `CLAUDE.md` in sync for Claude Code users (same policies, Claude paths).

## Hooks (dual Claude + Cursor protocol)

Scripts under `agentic/hooks/` are **shared**. They detect the runtime from stdin shape
(`hook_event_name` / `cursor_version` / `workspace_roots` ⇒ Cursor) via
`hooks/lib/hook-protocol.js`:

| Concern | Claude | Cursor |
|---------|--------|--------|
| Shell gate | `PreToolUse` Bash → `.tool_input.command`; deny = exit 2 | `beforeShellExecution` → `.command`; deny = `{permission:"deny"}` |
| Read gate | `PreToolUse` Read → `.tool_input.file_path` | `beforeReadFile` → `.file_path` |
| Write gate | `PreToolUse` Write/Edit → file path | `preToolUse` matcher `Write` (wired in `hooks.json`) |
| Format | `PostToolUse` Write/Edit | `afterFileEdit` → `.file_path` |
| Session start | `{hookSpecificOutput.additionalContext}` | `{additional_context}` |
| Session end | fire-and-forget audit + verify | same scripts; field aliases (`conversation_id`, …) |
| Action audit | *(not installed — TBD under `adapters/claude/hooks/`)* | `adapters/cursor/hooks/tool-audit.sh` → `docs/local/audit-cursor/<session>/` |

Action/tool audit is **per-IDE** (separate scripts and TSV files). Do not put audit logic back into shared `agentic/hooks/`.

## Claude mirror deactivation (anti-duplicate `/`)

Default `scripts/setup-agentic.sh cursor` **deactivates** the managed Claude mirror
(`.claude/.agentic-managed` paths only). Project overlays (`bcs-*`) stay.

- Restore Claude: `scripts/setup-agentic.sh claude`
- Dual-IDE: `scripts/setup-agentic.sh cursor --keep-claude`
- `all` keeps Claude populated

## Adaptation (not a plain copy)

Path rewrites on install:

- `.claude/skills/<framework>/` → `.cursor/skills/<framework>/` (not `bcs-*` overlays)
- `.claude/agents/` → `.cursor/agents/`
- `.claude/hooks/` → `.cursor/hooks/`

**No command→skill emission.** Personas live under `.cursor/agents/`; framework skills under
`.cursor/skills/` (including `/run`).

## Notes

- Hooks fail-open unless Cursor sets `failClosed: true` on a definition.
- `subagent-gate` must stay on a **pre**-write event (`preToolUse`); `afterFileEdit` cannot block.
