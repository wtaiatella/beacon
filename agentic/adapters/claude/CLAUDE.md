# Agentic Workspace — Claude Code (Unified, Ticket-Folder Workflow)

> **Canonical always-on context for Claude Code.** Installed to repo-root `CLAUDE.md` by
> `scripts/setup-agentic.sh claude` (root file is generated — do not edit it; edit this source).
> Cursor equivalent: `agentic/adapters/cursor/rules/*.mdc` → `.cursor/rules/` via `setup-agentic.sh cursor`.
>
> Framework SDD lives under `agentic/{agents,skills,commands,hooks}` and is installed as the
> user-level Claude plugin `beacon-sdd` (`/beacon-sdd:<name>`). Project skills, agents, and
> commands stay with the project; setup does not copy or link them. Cursor installs the same
> framework under a `beacon/` subfolder inside each `.cursor/` directory it uses.

@AGENTS.md
@WORKSPACE.md

The import above pulls in the **shared, IDE-agnostic** SDD contract (workspace identity, ticket
folder, personas, pipeline, confidence scoring, multi-repo, knowledge base, skills, hooks
(purpose), session memory, metrics, MCP, error protocol) — see `agentic/AGENTS.md` for the source.
Everything below is **specific to Claude Code** and intentionally lives only here.

## Personas — Claude Code invocation

Personas are invoked as plugin slash commands (`/beacon-sdd:<name>`). Each command is a **thin
delegator**: typing `/beacon-sdd:prd …` hands the invocation to the matching persona **subagent** in
the `beacon-sdd` plugin via the Task tool. The subagent does the work and returns a structured result;
when it needs a read-only helper or a human decision it escalates back to the main loop (see
**Flat orchestration** in `AGENTS.md`).

Three commands are not persona subagents: **`/run`** is main-loop orchestration driven by the
`run-pipeline` skill (there is no `run` subagent); **`/clone`**, **`/rebase`**, **`/kb-refresh`**,
and **`/kb-concentrator`** are thin utility commands that follow their matching `SKILL.md` directly
(no dedicated subagent).

The persona subagents are write-capable (tools: Read, Write, Edit, Bash, Grep, Glob) except
**`scrum`**, which is read-only (Read, Grep, Glob, Bash).

## Model Selection

**Claude Code sets the model per-subagent** in each agent's `model:` frontmatter. **Every agent's
canonical frontmatter is `model: inherit`** (uses whatever model the current session runs) —
available AI subscriptions/model tiers vary a lot per environment (home vs. work, which IDE,
which plan), so the framework no longer hardcodes an economy tier for any agent.

**Per-install override (optional, per adapter):** copy `agentic/models/example.yml` to
`agentic/models/claude.yml` (gitignored — local to this checkout) and list `<agent>: <model>` for
any agent you want on a different tier than `inherit` (e.g. `do: haiku`). `scripts/setup-agentic.sh
claude` applies it by rewriting the **installed** plugin copy's `model:` line for listed agents —
the canonical source under `agentic/agents/` is never touched. Re-run `setup-agentic.sh claude`
after editing the override file to apply changes; an unknown agent name in it prints a warning and
is otherwise ignored. Cursor reads its **own** `agentic/models/cursor.yml` — if you use both IDEs
in the same checkout (e.g. terminal vs. editor at the same job), each gets its own override file;
editing one never affects the other.

There is no Claude Code equivalent of per-run (mid-pipeline) model swapping; this override is
fixed per installation, not dynamic per step. The `run-pipeline` skill's `--model-strategy` /
`--budget` guidance is retained as guidance; automatic mid-run swaps are not performed under
Claude Code.

## Hooks (Claude Code wiring)

Registered in the `beacon-sdd` plugin `hooks/hooks.json`. Scripts live in that plugin and use
`${CLAUDE_PLUGIN_ROOT}`. See `AGENTS.md` — **Hooks** for what each one does; this table is the
Claude Code-specific event wiring:

| Script | Claude Code event | Matcher |
|--------|-------------------|---------|
| format-on-edit | PostToolUse | `Write\|Edit\|MultiEdit` |
| session-init | SessionStart | — |
| audit-log | SessionEnd | — |
| session-verify | SessionEnd | — |
| before-shell | PreToolUse | `Bash` |
| before-read | PreToolUse | `Read` |
| subagent-gate | PreToolUse | `Write\|Edit\|MultiEdit` |
