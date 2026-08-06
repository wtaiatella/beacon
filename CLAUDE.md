# Agentic Workspace — Claude Code (Unified, Ticket-Folder Workflow)

> This file is the always-loaded project context for **Claude Code**. It documents the workspace
> and sets boundaries; it does not itself route. This repo (`aw-unificado`) is **Claude Code
> only** — there is no `.cursor/` tree, no `.mdc` rule files, and no dual-IDE setup (FR-17). It was
> bootstrapped by copying the unchanged domain-persona machinery and the `prd`/`spectech`/`tasks`
> personas from `aw-pp`, and the six standalone `bcs-*`-derived tools from `aw-bcs`, then adapting
> the front end and control-file contract per this repo's unification initiative
> (`docs/specs/2026-07-15-unify-agentic-workflow/`).

## Workspace Identity

This is a company-wide Agentic Workspace for BMAD+SDD+GSD development with self-healing review loops. Spec-driven, token-efficient, dynamically gated.

BMAD frames delivery; SDD keeps specs authoritative; GSD ships thin vertical slices. Reviewers and `/scrum` close the loop at each gate.

**Core principle:** Agents write code and configuration. Agents never deploy. All deployments are handled by CI/CD. All code produced here is committed, pushed, and merged through GitLab MRs.

**One control-file convention, one orchestrator front end:** every ticket folder carries exactly
one machine-readable control file, `_state.json`, plus a human-readable `_notes.md` — never
`context.json`. The required orchestrator (`/run`) always starts at `/prd` → `/spectech` → `/tasks`;
there is no `/plan` and no single-`spec.md`-producing mode in this repo. See the `ticket-workflow`
skill for the full folder/schema contract.

## Personas (slash commands)

Personas are invoked as slash commands (`.claude/commands/*.md`). Each command file is a **thin delegator**: typing `/prd …` hands the invocation to the matching persona **subagent** (`.claude/agents/prd.md`) via the Task tool. The subagent does the work and returns a structured result; when it needs a read-only helper or a human decision it escalates back to the main loop (see **Flat Orchestration** below).

Three commands are not persona subagents: **`/run`** is main-loop orchestration driven by the `run-pipeline` skill (there is no `run` subagent); **`/clone`** is a workspace utility command; **`/kb-refresh`** and **`/kb-concentrator`** are thin utility commands that follow their matching `SKILL.md` directly (same shape as `/clone` — no dedicated subagent).

| Trigger | Role | Subagent | Input |
|---------|------|----------|-------|
| /prd | Product Requirements | `prd` | `<ticket-folder-path> [idea]` |
| /spectech | Technical Designer | `spectech` | `<ticket-folder-path>` |
| /tasks | Task Specialist | `tasks` | `<ticket-folder-path>` |
| /dev | Software Engineer | `dev` | `<ticket-folder-path>` |
| /sre | SRE & Platform Engineer | `sre` | `<ticket-folder-path>` |
| /data | Data & ML Engineer | `data` | `<ticket-folder-path>` |
| /qa | QA & Security Auditor | `qa` | `<ticket-folder-path>` |
| /fix | Debugger | `fix` | `<target-dir> [symptom]` |
| /do | Ad-Hoc Operator | `do` | `<target-dir> [task]` |
| /summary | Summary Writer | `summary` | `<ticket-folder-path>` |
| /scrum | PO / SM / PM | `scrum` | `<ticket-folder-path>` or reviewer report |
| /kb | Knowledge Base Builder | `kb` | `<target-dirs>` |
| /run | Pipeline Orchestrator | — (main loop + `run-pipeline` skill) | `<ticket-folder-path-or-jira-key> [idea] [flags]` |
| /clone | Repo Cloner (utility) | — | `<git-url> [target-dir]` |
| /ticket-intake | Standalone: Jira ticket intake | `ticket-intake` | `<JIRA-KEY \| jira-url>` |
| /repro | Standalone: local before/after defect reproduction | `repro` | `<ticket-folder \| JIRA-KEY> [--before\|--after]` |
| /flowchart-check | Standalone: flowchart-vs-code conformance | `flowchart-check` | `<ticket-folder \| JIRA-KEY>` |
| /rebase | Standalone: multi-repo git-sync | `rebase` | `[repo ...]` |
| /proof | Standalone: before/after proof (optional) | `proof` | `<ticket-folder \| JIRA-KEY>` |
| /build-test | Standalone: pecten regen + fast/full test tiers | `build-test` | `<ticket-folder \| JIRA-KEY> [--full]` |
| /kb-refresh | Standalone: incremental multi-repo KB refresh | — (thin command) | `[repo ...]` |
| /kb-concentrator | Standalone: global cross-repo KB concentrator | — (thin command) | `[flow-or-topic hint]` |
| /setup-workspace | Workspace tool registry setup | — (main loop + `setup-workspace` skill) | `[server-name ... \| --reset]` |

The persona subagents are write-capable (tools: Read, Write, Edit, Bash, Grep, Glob) except **`scrum`**, which is read-only (Read, Grep, Glob, Bash). Most run on `inherit`; `do` and `summary` run on `haiku`.

## Ticket-Folder Workflow (the only workflow)

Every unit of work — a support ticket or a feature — lives in one **ticket working folder**:

```
docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/      # with Jira key (e.g. BG-10965)
docs/specs/{YYYY-MM-DD}-{slug}/                   # without ticket key
├── _state.json      # machine state — the ONLY control file (see ticket-workflow skill)
├── _notes.md        # human/agent notes: decisions + "where to resume" per step
├── ticket.md        # issue definition + comments (ticket-intake, when used)
├── attachments/      # downloaded attachments, incl. marked *.drawio (ticket-intake, flowchart-check)
├── impact-analysis.md # plain-language complexity/blast-radius/blocker triage (ticket-intake, when used)
├── repro.md           # local before/after defect reproduction (repro, optional; feeds /prd)
├── prd.md            # product requirements (/prd)
├── spectech.md        # technical design, profile: lean|standard|full (/spectech)
├── tasks.md           # task list derived from prd.md + spectech.md (/tasks)
├── spec-review.md      # plan-segment (folder-mode) review outcome (plan-reviewer)
├── qa-report.md        # QA findings written by /qa (both standalone and orchestrated)
├── proof.md             # before/after practical proof (proof, optional)
└── summary.md            # post-pipeline handoff narrative (/summary)
```

**Required orchestrator (A) — the only orchestrator this repo builds:**

```
/run docs/specs/{slug}/           (or /run <JIRA-KEY> — scaffolds/finds the folder)
  → Task(prd) → Task(spectech) → Task(tasks) → Task(plan-reviewer, folder mode) → Task(scrum)
  → Task(dev)/Task(sre)/Task(data) as applicable, one or more phases
  → dev-reviewer/sre-reviewer/data-reviewer + security-scanner + Task(scrum) per phase
  → Task(qa) → Task(scrum) → Task(summary) → Finish
```

This is **exactly** today's implementation/review/QA/summary pipeline, with `/prd`→`/spectech`→
`/tasks` replacing the old single-`spec.md` front end. `/dev`, `/sre`, `/data`, `/qa`, `/scrum`,
`/summary` and their read-only helpers are carried over with **zero** change to their internal
prompts, gates, or confidence scoring — the only adaptation is that their input resolves from a
ticket-folder path (`prd.md`+`spectech.md`+`tasks.md`) instead of a single `spec.md`.

**Manual (equivalent, step by step):**

```
/prd docs/specs/{slug}/
/spectech docs/specs/{slug}/
/tasks docs/specs/{slug}/
/dev docs/specs/{slug}/   ← reads tasks.md directly
/sre docs/specs/{slug}/   ← reads tasks.md directly
/data docs/specs/{slug}/  ← reads tasks.md directly
/qa docs/specs/{slug}/
/summary docs/specs/{slug}/
```

`prd.md`, `spectech.md`, and `tasks.md` stay three separate, right-sized files — never merged into
one `spec.md`. `spectech.md`'s Lean/Standard/Full profile mechanism is the token/generality
control, reused unchanged.

**Standalone (B) — seven tools, invoked independently, never wired into the required orchestrator
above:** `ticket-intake`, `repro` (optional, local before/after defect reproduction — the newest
piece, native to this repo rather than ported from `aw-bcs`), `flowchart-check`, `rebase`
(multi-repo git-sync only), `proof` (optional), `build-test`, and the `kb-refresh`/`kb-concentrator`
pair. These read/write the same `_state.json`/`_notes.md` contract when scoped to a ticket folder
(all except `rebase`, which is not ticket-scoped, and `kb-refresh`/`kb-concentrator`, which operate
on `knowledge/` workspace-wide — see the `ticket-workflow` skill's Assumptions). They exist so a
**future**, separate ticket-oriented orchestrator variant can wire ticket intake and these pieces
together with verification checkpoints — that future orchestrator is not built here.

**Typical standalone sequencing (not enforced, just the common path):**
`/ticket-intake` → `/repro` (reproduce the reported bug locally, before any fix exists) → `/prd`
(consumes `repro.md` as confirmed evidence) → … → `/dev` implements the fix → `/repro --after`
(confirm the fix against the same scenario) → `/proof` (optional, final before/after) → `/summary`.

## Supporting Subagents

All subagents live under `.claude/agents/` and are invoked via the Task tool (auto-delegated by description, or explicitly: "use the codebase-explorer agent"). Besides the persona subagents above, three families of **read-only** helpers support the pipeline — they never mutate repo state and return structured findings to the invoking persona, orchestrator, or user.

**Reviewers, scanners, and scouts (read-only):**

| Name | Role | Model | Tools | Used By |
|------|------|-------|-------|---------|
| codebase-explorer | Target directory scout | haiku | Read, Grep, Glob, Bash | /fix, /kb |
| spec-validator | Spec compliance checker | haiku | Read, Grep, Bash | /qa |
| security-scanner | Security vulnerability scanner | inherit | Read, Grep, Bash | /qa, /run phase gate |
| plan-reviewer | Spec quality reviewer | haiku | Read, Grep, Glob | /run — folder mode (after prd/spectech/tasks) |
| dev-reviewer | Code quality reviewer | haiku | Read, Grep, Glob | /run (after /dev) |
| sre-reviewer | Infra quality reviewer | haiku | Read, Grep, Glob | /run (after /sre) |
| data-reviewer | Data quality reviewer | haiku | Read, Grep, Glob | /run (after /data) |
| pre-plan-triage | Pre-plan context router | haiku | Read | /run (before the PRD/Spectech/Tasks segment) |

**Front-end personas (write-capable):**

| Name | Role | Model | Tools | Used By |
|------|------|-------|-------|---------|
| prd | Product requirements analyzer | inherit | Read, Write, Edit, Bash, Grep, Glob | /prd command |
| spectech | Technical specification designer | inherit | Read, Write, Edit, Bash, Grep, Glob | /spectech command |
| tasks | Task breakdown specialist | inherit | Read, Write, Edit, Bash, Grep, Glob | /tasks command |

**Standalone pieces (write-capable, not pipeline-wired) — six ported from `aw-bcs`, `repro` native to this repo:**

| Name | Role | Model | Tools | Used By |
|------|------|-------|-------|---------|
| ticket-intake | Jira ticket intake, project-agnostic | inherit | Read, Write, Edit, Bash, Grep, Glob | /ticket-intake command |
| repro | Local before/after defect reproduction — delegates all infra to `/sandbox`, drives the UI scenario via Chrome DevTools MCP (optional; feeds /prd) | inherit | Read, Write, Edit, Bash, Grep, Glob, scoped Chrome DevTools MCP | /repro command |
| flowchart-check | Scoped flowchart-vs-code conformance | inherit | Read, Grep, Glob, Bash | /flowchart-check command |
| rebase | Multi-repo git-sync (checkout main → pull → checkout back → rebase) | inherit | Read, Write, Edit, Bash, Grep, Glob | /rebase command |
| proof | Before/after practical proof (optional) | inherit | Read, Write, Edit, Bash, Grep, Glob | /proof command |
| build-test | Pecten regen + fast/full test tiers | inherit | Read, Write, Edit, Bash, Grep, Glob | /build-test command |

**Enterprise MCP specialists (read-only, `haiku`):** `mcp-arc`, `mcp-confluence`, `mcp-gitlab`, `mcp-jira`, `mcp-glean`. Persona subagents must **not** call enterprise MCP tools directly; they emit a `REQUEST_MAIN:` escalation with a specialist label and query, and the main loop runs the matching `mcp-*` subagent via Task and feeds the bounded result back.

> **Flat orchestration (Claude Code execution model):** subagents cannot spawn further
> subagents. Only the **main conversation loop** schedules `Task(...)` — it invokes both
> persona subagents and the read-only helpers. A persona subagent that needs a helper,
> an MCP specialist, or a human decision returns an escalation line the main loop honors:
> `REQUEST_MAIN:` (run the named helper/`mcp-*` subagent), `QUESTION:` / `ASK_USER`
> (ask the user), or `APPROVAL_NEEDED:` (stop-for-approval). `/run` is likewise pure
> main-loop orchestration driven by the `run-pipeline` skill. See
> `.claude/skills/run-pipeline/SKILL.md` and `.claude/commands/run.md`.

## Pipeline

- **Manual:** /prd → /spectech → /tasks → /dev+/sre+/data → /qa → /summary → merge
- **Parallel tracks:** /dev, /sre, /data run in parallel when the spec allows; otherwise order by phases
- **Phased specs:** the §6 implementation gate (`*-reviewer` + `Task(scrum)`) is **required between** implementation phases — never chain `Task(dev|sre|data)` for phase k+1 before §6 completes for phase k
- **Orchestrated:** /run — main loop follows the `run-pipeline` skill; full pipeline end-to-end (PRD/Spectech/Tasks → implement → review → QA → summary), auto by default
- **Auto:** pauses only for genuine questions or low confidence
- **`--review`:** opt-in checkpoints after each step
- **`--manual`:** manual step gates (pause after the plan segment and each domain track: Proceed / Force review / Add context and review) — not manual models
- **`--confidence N`:** overrides default pass threshold (see Confidence)
- **`--skip <step>`:** skip plan (the PRD/Spectech/Tasks segment), plan-review, `impl-review`, qa, or summary
- **`--branch [name]`:** **suggests** a branch; the user must still confirm creation on protected branches — no silent auto-create
- **`--resume`:** resume from last successful step after a failure
- **`--max-iterations N`:** override implementation/review rework caps
- **`--max-plan-iterations N`:** override the PRD/Spectech/Tasks ↔ plan-reviewer loop caps (default 3)
- **Escape hatches:** /fix (bugs), /do (quick tasks) — **Ticket-folder amendment:** re-run `/prd`/`/spectech`/`/tasks` over the existing folder with "changes"

**Reject invalid orchestration:** treat a `/run` as failed (do not report success) if you see `ORCHESTRATION_ABORTED`, single-agent implementation instead of `Task` delegations, `Skipped:` of the PRD/Spectech/Tasks segment/qa/summary/reviews without the matching `--skip`, a single `Task(dev|sre|data)` spanning multiple `### Phase N:` blocks, or a persona editing `tasks.md` checkboxes/`_state.json`/`status` before `Task(scrum)` PROCEED. Full list in the `run-pipeline` skill.

## Git and GitLab mutations (paramount)

- **Persona subagents must never** run `git commit`, `git push`, or mutating GitLab actions.
- **The orchestrator (main loop) must never** *silently* auto-push, auto-create/open an MR, or invoke mutating GitLab APIs. It **may** perform these via the GitLab MCP (`mcp__GitLab__*`) after **explicit user confirmation** at that step (see below).
- **Exception — Finish commit:** the main loop may run `git add -A` and `git commit -m '…'` **only** when the user explicitly selects an orchestrator-offered commit message (or gives equivalent explicit intent). If the user chooses "do not commit" / "other-manual", do not commit.
- **Push:** the main loop may run `git push` (including `--force-with-lease` when a confirmed history rewrite requires it) after an explicit user "Yes" to a push prompt. Never auto-push silently.
- Each branch creation and each mutating GitLab action (MR create/update, write API) requires **explicit user confirmation at that step**. Once confirmed, the main loop performs MR create/update **via the GitLab MCP** (`mcp__GitLab__*`), always presenting the MR title/body for review first. See the `gitlab-mr-from-spec` skill and `scripts/tools/mr-description-from-spec.sh` for body content. `rebase` (the standalone multi-repo git-sync tool) never creates or updates an MR and never transitions a Jira ticket — that responsibility was deliberately dropped when narrowing it from the old `bcs-mr`.
- GitLab operations use the **GitLab MCP** (`mcp__GitLab__*`) as the primary tool, run only after the user confirms. `glab` is **not** used in this workspace (not authenticated); do not suggest it.

## Confidence Scoring

- Per-persona reviewers emit 0–100% scores including spec alignment
- /scrum (PO/SM/PM) evaluates at each gate with business judgment
- **≥ threshold (default 75%):** PROCEED
- **50–74%:** ASK_USER
- **< 50%:** REWORK (automatic)
- **Max loops hit:** ESCALATE
- /scrum may override defaults when business context warrants
- Threshold is per-gate; document overrides in the ticket folder or session notes when non-default
- If domains differ in risk, define per-domain weights or minimums in `spectech.md`

## Spec Format (ticket-folder contract)

- Path: `docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/` (with Jira key) or `docs/specs/{YYYY-MM-DD}-{slug}/` (without key) — one folder per ticket
- Control file: `_state.json` (machine-readable — schema below) + `_notes.md` (human-readable running log). **`context.json` is never created** — see the `ticket-workflow` skill's AC-1 regression guard: any step that finds both files in the same folder must stop and surface the collision.
- `_state.json.steps` is an **open** string-keyed map: the required orchestrator's six keys (`prd`, `spectech`, `tasks`, `implement`, `code_review`, `summary`), or a standalone piece's own key (e.g. `ticket_intake`, `impact_analysis`, `repro`, `flowchart_check`, `build_test`, `proof`). Values: `pending | in_progress | done | blocked | skipped`.
- `prd.md`, `spectech.md`, `tasks.md` — three separate files (never merged); `spectech.md`'s frontmatter declares `profile: lean|standard|full`.
- Domain tags on `tasks.md` checkboxes: `[dev]`, `[sre]`, `[data]`; multi-repo: `[dev:repo]`
- Phases for cross-repo dependencies
- Shorthand: full folder path, slug match, `latest`, or a Jira key that resolves to/creates a folder

See the `ticket-workflow` skill for the full `_state.json` schema, `_notes.md` convention, and stop-gate/HITL rules — every piece that touches a ticket folder's control file reads this one skill instead of re-describing the schema.

## Multi-Repo

- Target repos are cloned as subdirectories of the workspace root and are gitignored (per-developer, not tracked)
- Add one with **`/clone <git-url> [target-dir]`** — clones into the root and registers it in the inventory
- The inventory (repo name + current branch) is detected dynamically and injected into context on session start by the `session-init` hook — no need to list repos manually
- Scope tables in specs list involved repos
- `[domain:repo]` task tags
- Phases order dependencies
- Within phases: parallel. Between phases: sequential.
- Single-repo work: omit `:repo` tags; scope table may list one repo only
- `rebase` (standalone) and `kb-refresh` (standalone) both iterate every child repo directly, independent of any ticket folder

## Knowledge Base

**Preferred source of curated context is ARC MCP (AvaTax Release Central)** — see `docs/reference/arc-mcp-workflow.md`. `/prd` uses ARC first when configured (in-session, standalone use — see the `run-pipeline` skill's ARC lanes). The local `/kb` knowledge base below is the **fallback** for repos not onboarded to ARC.

Structured project context at `knowledge/{project-name}/` (tracked in git, shared across the team).
- Folder per project: `_index.md` (always loaded, ~50 lines) + section files loaded on demand (architecture, api, data-models, dependencies, infrastructure, conventions)
- Built by `/kb <target-dir>` — expensive, manual, full-rebuild-per-project. Run on first onboarding or after major restructuring.
- **Incremental, multi-repo-aware refresh:** `/kb-refresh` (standalone) — for every child repo, pulls the main branch and diff-classifies what changed to decide which `knowledge/{project}/` need updating; distinct from `/kb`'s manual full rebuild.
- **Cross-repo, system-level view:** `/kb-concentrator` (standalone) — maintains `knowledge/global-kb/`, the aggregated view of how projects call into each other (end-to-end flows, integration boundaries). Typically chained after `/kb-refresh`.
- Consumed by `/prd` (loads index + relevant sections, falls back to codebase-explorer if KB absent)
- `/run` warns if KB is missing but does **not** auto-invoke `/kb`

## Skills

Defined under `.claude/skills/`.
- **ticket-workflow** — single source of truth for the `_state.json` schema, `_notes.md` convention, and stop-gate/HITL rules; every piece that touches a ticket folder reads this instead of re-describing the schema
- **run-pipeline** — /run (the authoritative end-to-end orchestration workflow the main loop follows — PRD/Spectech/Tasks segment → implement → review → QA → summary)
- **generate-prd** / **generate-spectech** / **generate-tasks** — the `/prd`/`/spectech`/`/tasks` personas' normative document templates, adapted to read/write `_state.json`+`_notes.md`
- **generate-impact-analysis** — `/ticket-intake`'s normative template for `impact-analysis.md`, a plain-language (no jargon) triage doc covering complexity, likely modification points, involved repos, and blockers/related work — investigative recon, not requirements/design (that stays `/prd`'s and `/spectech`'s job)
- **prd-validator** / **prd-discovery** — supporting skills for `/prd` (implicit-requirements/scope validation; brainstorm phase), adapted to the same control-file contract
- **generate-spec** — retained only as a reference for `plan-reviewer.md`'s single-file-mode completeness check (unchanged persona, FR-7); nothing in this repo produces single-file specs anymore
- **review-report** — /qa (structured QA + security narrative)
- **deploy-checklist** — /sre (CI/CD coverage checklist, 5-tier: dev/qa/int/sbx/prd)
- **confidence-scoring** — reviewers + /scrum (per-domain weights, sub-scores, trend analysis, calibration)
- **knowledge-base** — /kb (output structure; DEPRECATED for new projects in favor of ARC MCP — fallback only)
- **gitlab-mr-from-spec** — /summary + finish (spec-driven MR body text for user-run GitLab actions; no autonomous commit/push/MR)
- **kb-refresh** / **kb-concentrator** — standalone, incremental multi-repo KB tooling (see Knowledge Base above); thin utility commands, same shape as `/clone`

## Model Selection

**Claude Code sets the model per-subagent** in each agent's `model:` frontmatter:

- **`inherit`** (session model) — implementers, architects, debuggers: prd, spectech, tasks, dev, sre, data, qa, fix, kb, security-scanner, ticket-intake, repro, flowchart-check, rebase, proof, build-test.
- **`haiku`** (economy) — reviewers, validators, and mechanical/short-context agents: do, summary, scrum, codebase-explorer, spec-validator, plan-reviewer, dev-reviewer, sre-reviewer, data-reviewer, pre-plan-triage, mcp-*.

There is no Claude Code equivalent of per-run model swapping; pick the session model by workflow (standard for routine `/run`, premium for a complex `/fix`). The `run-pipeline` skill's `--model-strategy` / `--budget` guidance is retained as guidance; automatic mid-run swaps are not performed under Claude Code.

## Hooks

Registered in `.claude/settings.json`; scripts live in `.claude/hooks/`.

| Script | Claude Code event | Matcher | Purpose |
|--------|-------------------|---------|---------|
| format-on-edit | PostToolUse | `Write\|Edit\|MultiEdit` | Auto-format edited file with the project formatter |
| session-init | SessionStart | — | Inject child-repo inventory (name + branch) + active session id + spec status + session memory |
| audit-log | SessionEnd | — | Append session record (6-col TSV) to local audit log |
| session-verify | SessionEnd | — | Verify no uncommitted secrets, hook health, spec inconsistencies, session status summary |
| before-shell | PreToolUse | `Bash` | Block dangerous commands (rm -rf, DROP TABLE, force-push to protected branches) |
| before-read | PreToolUse | `Read` | Block reading .env, credentials, private keys, secrets files |
| subagent-gate | PreToolUse | `Write\|Edit\|MultiEdit` | Block writes when the target's child repo is on a protected branch (main, master, develop, release/*); workspace root is excluded |

Hooks fail-open: failures log but don't block. `subagent-gate` has no override — writes to protected branches are always refused.

## Session Memory

Ephemeral scratch per session at `docs/sessions/<session-id>/current.md` (gitignored). The active `session-id` is stored in `docs/sessions/ACTIVE_SESSION`.
- Read: `scripts/tools/session-memory.sh read`
- Write: `scripts/tools/session-memory.sh write "DECISION: chose PostgreSQL for sessions"`
- Clear: `scripts/tools/session-memory.sh clear`
- Categories: DECISION, QUESTION, GATE, or free-form context. Optional post-`/run` audit lines (human only): `COMMIT_SUGGESTIONS:`, `PUSH_CONFIRMED:`, `MR_TARGET_BRANCH:`, `MR_CONFIRMED:`.
- Injected into context on session start via the `session-init` hook (includes the active session id + path).
- **Cleanup:** stale session files (untouched >24h) are deleted at next session start; empty session dirs may be removed afterward. Not a timer — only pruned when a new session begins.
- **Two-layer state:** this is the ephemeral, cross-session-agnostic **orchestration-run** checkpoint (crash-resume for one `/run`). It is separate from — and does not replace — each ticket's own persistent `_state.json`/`_notes.md`, which is the per-ticket, cross-session audit trail (see the `ticket-workflow` skill). Not a database. Not a replacement for the ticket folder.

## Metrics

Local-only pipeline and agent metrics: `scripts/tools/metrics.sh [overview|agents|specs|gates|sessions|models|cost|export|budget-check]`.
Aggregates data from `docs/audit.log`, `docs/sessions/`, and optional `docs/usage-events.tsv`. Nothing leaves the machine.

## MCP

Servers are configured in `.mcp.json`; teams add or remove them as needed. All personas work without MCP — it is never required for the core flow.

Enterprise MCP access is **mediated through the read-only `mcp-*` specialist subagents** (`mcp-arc`, `mcp-confluence`, `mcp-gitlab`, `mcp-jira`, `mcp-glean`), scheduled only by the main loop. Persona subagents never call enterprise MCP tools directly; they escalate with `REQUEST_MAIN: <specialist> <query>` and the main loop runs the matching specialist via Task. When ARC MCP is configured, `/prd` prefers it for AvaTax/project/schema context. `ticket-intake` uses the Jira MCP directly for its own intake fetch (unchanged from its `aw-bcs` origin).

## Error Protocol

1. **Missing arguments:** ask user; show expected syntax
2. **Ticket folder not found:** search `docs/specs/` for matches; suggest `/prd <new-folder>` or `/ticket-intake <JIRA-KEY>`
3. **Target dir not found:** list dirs; ask confirmation
4. **Tool failure (non-zero exit):** show error, explain, suggest fix; never silently proceed
5. **MCP unavailable:** warn; continue; degrade gracefully
6. **Ambiguous intent:** one clarifying question
7. **Scope creep:** stop; recommend a `/prd` amendment (re-run `/prd` over the existing ticket folder)
8. **Hook failure:** fail-open; log; do not block
9. **Orchestration failure:** /run stops and reports; QA loops capped at 3; review loops at 2; surface last step and suggested next action
10. **Reviewer override:** log actor, reason, and prior score for audit trail
11. **Two control files detected (`context.json` + `_state.json`):** stop and surface the collision — never silently prefer one (AC-1 regression guard, per the `ticket-workflow` skill)
