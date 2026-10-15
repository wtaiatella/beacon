# Beacon SDD Workspace — Google Antigravity (AGY) Router

> **Antigravity always-on plugin context** (equivalent role to root `CLAUDE.md` for Claude Code or `00-workspace-router.mdc` for Cursor).
> Canonical SDD source lives under `agentic/`; install with `scripts/setup-agentic.sh antigravity`.
> Project skills, agents, and commands stay with the project. Setup does not copy or link them.
>
> The **shared, IDE-agnostic** SDD contract (workspace identity, ticket folder, personas, pipeline,
> confidence scoring, multi-repo, knowledge base, skills, hooks (purpose), session memory, metrics,
> MCP, error protocol) lives in root `AGENTS.md` (source: `agentic/AGENTS.md`) — Antigravity reads it
> natively upon loading any workspace.

## Where things live (Antigravity Global Plugin)

| Kind | Path |
|------|------|
| Plugin root | `~/.gemini/config/plugins/beacon-sdd/` |
| Plugin manifest | `~/.gemini/config/plugins/beacon-sdd/plugin.json` |
| Framework skills & personas | `~/.gemini/config/plugins/beacon-sdd/skills/` |
| Rules | `~/.gemini/config/plugins/beacon-sdd/rules/` |
| Hooks | `~/.gemini/config/plugins/beacon-sdd/hooks.json` + `hooks/` |
| Workspace contract | Root `AGENTS.md` in each target repo |
| Canonical source | `agentic/` (edit here, then re-run setup) |

## Personas & Commands — Antigravity Invocation

In Antigravity IDE and Antigravity 2.0, personas and commands operate through **Progressive Disclosure Skills**.
Typing slash commands in chat (or delegating during `/run`) activates the corresponding skill:

| Trigger | Role | Skill Name | Input / Contract |
|---------|------|------------|------------------|
| `/run` | Pipeline Orchestrator | `run` / `run-pipeline` | `<ticket-folder-path-or-jira-key> [idea] [flags]` |
| `/prd` | Product Requirements | `prd` | `<ticket-folder-path> [idea]` |
| `/spectech` | Technical Designer | `spectech` | `<ticket-folder-path>` |
| `/tasks` | Task Specialist | `tasks` | `<ticket-folder-path>` |
| `/dev` | Software Engineer | `dev` | `<ticket-folder-path>` |
| `/qa` | QA & Security Auditor | `qa` | `<ticket-folder-path>` |
| `/scrum` | PO / SM / PM Reviewer | `scrum` | `<ticket-folder-path>` or reviewer report |
| `/sre` | SRE & Platform Engineer | `sre` | `<ticket-folder-path>` |
| `/data` | Data & ML Engineer | `data` | `<ticket-folder-path>` |
| `/fix` | Debugger | `fix` | `<target-dir> [symptom]` |
| `/do` | Ad-Hoc Operator | `do` | `<target-dir> [task]` |
| `/summary` | Summary Writer | `summary` | `<ticket-folder-path>` |
| `/clone` | Repo Cloner (utility) | `clone` | `<git-url> [target-dir]` |
| `/rebase` | Multi-repo git-sync | `rebase` | `[repo ...] [ticket-key]` |
| `/kb` | Knowledge Base Builder | `kb` | `<target-dirs>` |
| `/kb-refresh` | Standalone KB refresh | `kb-refresh` | `[repo ...]` |
| `/kb-concentrator` | Cross-repo KB concentrator | `kb-concentrator` | `[flow-or-topic hint]` |
| `/setup-workspace` | Tool registry setup | `setup-workspace` | `[server-name ...]` |

## Antigravity Native Tool Mapping

When executing instructions from personas or skills, translate abstract tool references to Antigravity native tools:
- **Bash / Shell:** `run_command` (always pass `Cwd` within workspace).
- **Read / ReadFile:** `view_file` (pass `AbsolutePath`).
- **Write / FileCreate:** `write_to_file` (pass `TargetFile`).
- **Edit / MultiEdit:** `replace_file_content` / `multi_replace_file_content` (pass `TargetFile`).
- **Grep / Glob:** `grep_search` / `list_dir`.
- **AskUser / Prompt:** `ask_question`.

## Flat Orchestration

- The main chat session drives `/run` following the `run-pipeline` skill.
- Skills operate with Least-Privilege Prompting (LPP): worker skills focus strictly on their assigned domain slice.
- No direct enterprise MCP from worker personas: use `REQUEST_MAIN: <specialist> <query>` for orchestrator-mediated context.
