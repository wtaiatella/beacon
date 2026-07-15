# Claude Code Port

This workspace was originally built for **Cursor** (`.cursor/`). It now ships a parallel
**Claude Code** configuration (`.claude/`, `CLAUDE.md`, `.mcp.json`) so the same
spec-driven, gated pipeline runs in either tool — a dual-IDE setup kept **in sync with
the `development` branch** framework (not `main`). The `.cursor/` tree is otherwise
untouched; the one intentional edit is `.cursor/hooks/session-init.sh`, which gained the
same session-start child-repo inventory as the Claude side (dual-IDE parity).

## Init / setup

| Tool | Command |
|------|---------|
| Claude Code | `./scripts/setup-claude.sh` |
| Cursor | `./scripts/setup.sh` |

`setup-claude.sh` checks prerequisites (Node ≥18, git, Claude Code CLI), makes hook and
tool scripts executable, creates runtime dirs, and validates the `.claude/` structure +
`settings.json ↔ hook-script` sync (relationship-based, no hardcoded counts).

## Inventory (kept in parity with `.cursor/`)

| Kind | Count | Location |
|------|-------|----------|
| Subagents | 24 | `.claude/agents/` |
| Commands | 16 | `.claude/commands/` (11 personas + 3 helper + `/run` + `/clone`) |
| Skills | 7 | `.claude/skills/` |
| Hooks | 7 | `.claude/hooks/` (registered in `.claude/settings.json`) |

The 24 subagents = 11 personas (plan, dev, sre, data, qa, fix, do, summary, scrum, kb,
roadmap) + 8 read-only helpers (codebase-explorer, spec-validator, security-scanner,
plan/dev/sre/data-reviewer, pre-plan-triage) + 5 MCP specialists (mcp-arc, mcp-confluence,
mcp-gitlab, mcp-jira, mcp-glean).

## What maps to what

| Concept | Cursor | Claude Code |
|---------|--------|-------------|
| Always-on context | `.cursor/rules/00-workspace-router.mdc` + `run-pipeline-trigger.mdc` + `git-gitlab-mutations.mdc` | `CLAUDE.md` (all three folded in) |
| Personas | `.cursor/agents/*.md` (native `/name`) | `.claude/agents/*.md` (subagents) **+** `.claude/commands/*.md` (thin `/name` delegators) |
| Helpers / MCP specialists | `.cursor/agents/*.md` | `.claude/agents/*.md` (subagents via Task) |
| `/run` orchestration | `run-pipeline` skill + trigger rule (no run subagent) | `.claude/commands/run.md` → main loop reads `.claude/skills/run-pipeline/SKILL.md` |
| Skills | `.cursor/skills/*` | `.claude/skills/*` |
| Hooks config | `.cursor/hooks.json` | `.claude/settings.json` (`hooks` + `matcher`) |
| Hook scripts | `.cursor/hooks/*.sh` | `.claude/hooks/*.sh` (rewritten I/O) |
| Project MCP | `.cursor/mcp.json` | `.mcp.json` |
| Model assignment | `.cursor/models.yml` + `apply-models.sh` | per-subagent `model:` frontmatter |

## Key translation decisions

### 1. Flat orchestration maps cleanly
`development` already uses **flat orchestration**: only the main session schedules
`Task(...)`; personas never nest tasks and escalate via `REQUEST_MAIN:` / `QUESTION:` /
`APPROVAL_NEEDED:`. Claude Code subagents **cannot spawn subagents**, so this maps
directly: personas + helpers are subagents; the **main loop** (a persona `/command` or
`/run`) does all `Task` delegation and honors escalations. `/run` is not a subagent — the
main loop reads the `run-pipeline` skill and orchestrates.

### 2. Hook events & protocol
Cursor event names and I/O differ from Claude Code's:

| Cursor event | Claude Code event (matcher) |
|--------------|------------------------------|
| `beforeShellExecution` | `PreToolUse` (`Bash`) |
| `beforeReadFile` | `PreToolUse` (`Read`) |
| `subagentStart` | `PreToolUse` (`Write\|Edit\|MultiEdit`) — see note |
| `afterFileEdit` | `PostToolUse` (`Write\|Edit\|MultiEdit`) |
| `sessionStart` | `SessionStart` |
| `sessionEnd` | `SessionEnd` |

Each script was rewritten: input reads from `.tool_input.command` / `.tool_input.file_path`
(Cursor used top-level fields); blocking uses **exit code 2 + stderr** (Cursor used
`{permission:"deny"}`); `session-init` returns `{hookSpecificOutput:{hookEventName:
"SessionStart", additionalContext}}`; `settings.json` paths use `$CLAUDE_PROJECT_DIR`.
`development`'s logic additions were carried over: `audit-log` writes a 6-column TSV;
`session-verify` adds a status summary; `session-init` reports the active session id
(`ACTIVE_SESSION`) **and** — a Claude-port addition — a live child-repo inventory.

**`subagent-gate` semantic change:** Cursor blocked write-capable *agents* at
`subagentStart`. Claude Code has no read-only-subagent signal, so the port gates the
actual `Write`/`Edit`/`MultiEdit` tool calls by the target file's repo branch. Same policy
(no writes to protected branches), enforced at the write. Read-only agents never write, so
they are unaffected.

### 3. Model mapping
Cursor tiers → Claude `model:` frontmatter: session/default → `inherit`; economy
(`composer-2`) → `haiku`. There is no Claude equivalent of per-run `apply-models.sh` swaps.

### 4. `/clone` and repo inventory (Claude-port additions)
`/clone <git-url> [dir]` (`scripts/tools/clone-repo.sh`) clones a target repo into the
workspace root; the `session-init` hook auto-detects all child repos each session, so
multi-repo tickets need no manual repo listing.

## Verifying inside Claude Code
- `./scripts/setup-claude.sh` — expect 24 subagents, 16 commands, 7 skills, 7 hooks, all synced.
- `/hooks` — confirm the 7 hooks are registered.
- Type `/` — confirm personas, `/run`, `/clone`, and the 3 helper commands.
- On first launch, approve the project `.mcp.json` / `.claude/settings.json` when prompted.

## Not ported (Cursor-only, no Claude equivalent needed)
- `.cursor/models.yml` / `.cursor/models.user.yml` / `scripts/tools/apply-models.sh` — model is set per-subagent instead.
- `.cursor/settings.json` — empty (`{}`) in `development`; nothing to port.
- `scripts/setup.sh` — kept for Cursor users.
