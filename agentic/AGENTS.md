# Agentic Workspace — SDD (canonical, IDE-agnostic)

> **Canonical source of truth** for how this SDD workspace operates — personas, ticket-folder
> workflow, the `/run` pipeline, confidence scoring, multi-repo rules, and the error protocol.
> Installed to repo-root `AGENTS.md` by `scripts/setup-agentic.sh <claude|cursor|all>` — this file
> is read natively by Cursor, and imported by Claude Code's root `CLAUDE.md` via `@AGENTS.md`.
> **Edit this source, not the generated root copy.**
>
> What is **not** here (lives in each IDE's own thin adapter file instead, because it genuinely
> differs per tool): exact invocation mechanics (slash command → plugin/agent wiring), the model
> (`model:` frontmatter vs. dynamic per-step override) selection table, and the hooks table (exact
> event/matcher names differ between Claude Code and Cursor). See `CLAUDE.md` (Claude Code) or
> `.cursor/rules/beacon/00-workspace-router.mdc` (Cursor) for those.
>
> This file never contains content specific to a **target/child repository** (tech stack, that
> project's own conventions, a developer's personal working style for that codebase). That belongs
> in the target repo's own `CLAUDE.md` / `AGENTS.md`, never here — this file is purely about how
> the SDD framework itself operates, independent of which repo it is pointed at.

## Workspace Identity

This is a spec-driven (SDD) development workspace with self-healing review loops: staged, gated,
and token-efficient instead of free-form chat.

SDD keeps `prd.md` / `spectech.md` / `tasks.md` authoritative over scope, architecture, and
acceptance — not chat history. GSD (thin vertical slices) keeps each implementation phase small
and independently testable instead of one monolithic change. Reviewers and `/scrum` close the loop
at every gate (plan segment, per-phase implementation, post-QA).

**Core principle:** Agents write code and configuration. Agents never deploy. All deployments are
handled by CI/CD. All code produced here is committed, pushed, and merged through GitLab MRs.

**One control-file convention, one orchestrator front end:** every ticket folder carries exactly
one machine-readable control file, `_state.json`, plus a human-readable `_notes.md` — never
`context.json`. The required orchestrator (`/run`) always starts at `/prd` → `/spectech` → `/tasks`;
there is no `/plan` and no single-`spec.md`-producing mode in this repo. See **Spec Format
(ticket-folder contract)** below for the full folder/schema contract.

**Canonical framework source:** edit SDD agents/skills/commands/hooks under `agentic/` (not scanned
by IDEs). Install into a runtime with `scripts/setup-agentic.sh claude|cursor|antigravity|all`.
Project skills, agents, and commands stay outside `agentic/`. Setup does not copy or link them,
and prunes a path only when that runtime's `.agentic-managed` manifest lists it.

## Personas

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
| /rebase | Multi-repo git-sync (utility) | — (thin command) | `[repo ...] [ticket-key]` (empty args: infer one conversation ticket and its repo — `_state.json` fallback — else all child repos) |
| /kb-refresh | Standalone: incremental multi-repo KB refresh | — (thin command) | `[repo ...]` |
| /kb-concentrator | Standalone: global cross-repo KB concentrator | — (thin command) | `[flow-or-topic hint]` |
| /setup-workspace | Workspace tool registry setup | — (main loop + `setup-workspace` skill) | `[server-name ... \| --specialist <name> \| --reset]` |

Project skills, agents, and commands are optional and **outside** the SDD required path.
SDD personas must not depend on them. Setup does not place them.

`scrum` is **read-only**. All other persona subagents are write-capable. Personas escalate helpers,
enterprise MCP, or human decisions with `REQUEST_MAIN:` / `QUESTION:` / `ASK_USER` /
`APPROVAL_NEEDED:` — only the **main loop** schedules the next delegation (see **Flat
orchestration** below). Exact per-tool invocation mechanics (e.g. plugin slash commands vs. agent
definitions) are documented in your IDE's adapter file.

## Ticket-Folder Workflow (the only workflow)

Every unit of work — a support ticket or a feature — lives in one **ticket working folder**:

```
docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/      # with Jira key (e.g. BG-10965)
docs/specs/{YYYY-MM-DD}-{slug}/                   # without ticket key
├── _state.json      # machine state — the ONLY control file (see Spec Format below)
├── _notes.md        # human/agent notes: decisions + "where to resume" per step
├── ticket.md        # optional issue definition + comments (when present)
├── attachments/      # optional attachments
├── prd.md            # product requirements (/prd)
├── spectech.md        # technical design, profile: lean|standard|full (/spectech)
├── tasks.md           # task list derived from prd.md + spectech.md (/tasks)
├── spec-review.md      # plan-segment (folder-mode) review outcome (plan-reviewer)
├── qa-report.md        # QA findings written by /qa (both standalone and orchestrated)
└── summary.md            # post-pipeline handoff narrative (/summary)
```

**Required orchestrator — the only orchestrator this repo builds:**

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

**Framework utilities (not pipeline-wired):** `/clone` (register a child repo), `/rebase`
(multi-repo git-sync), `/kb-refresh` / `/kb-concentrator` (knowledge), `/setup-workspace`
(tool registry). These share the workspace but are not steps of `/run`.

**Project skills, agents, and commands (optional, outside SDD):** kept by the project, not under
`agentic/`, and not installed by setup. They may write extra files into a ticket folder when used,
but **SDD personas and the required orchestrator must not require them**.

## Supporting Subagents

Besides the persona subagents above, three families of **read-only** helpers support the pipeline —
they never mutate repo state and return structured findings to the invoking persona, orchestrator,
or user. (Which model tier each runs on is an IDE-specific detail — see your adapter file; roles
and responsibilities below are shared.)

**Reviewers, scanners, and scouts (read-only):**

| Name | Role | Used By |
|------|------|---------|
| codebase-explorer | Target directory scout | /fix, /kb |
| spec-validator | Spec compliance checker | /qa |
| security-scanner | Security vulnerability scanner | /qa, /run phase gate |
| plan-reviewer | Spec quality reviewer | /run — folder mode (after prd/spectech/tasks) |
| dev-reviewer | Code quality reviewer | /run (after /dev) |
| sre-reviewer | Infra quality reviewer | /run (after /sre) |
| data-reviewer | Data quality reviewer | /run (after /data) |
| pre-plan-triage | Pre-plan context router (also classifies `project_maturity`: greenfield/brownfield) | /run (before the PRD/Spectech/Tasks segment) |
| pre-plan-reviewer | Pre-plan grounding critic (gaps/inconsistency/ambiguity, before `/prd` ever runs) | /run (after the pre-plan merge, before `Task(prd)`) |

**Pre-plan domain specialists (read-only; the default, always-available pre-plan grounding — no MCP/config required):**

| Name | Role | Used By |
|------|------|---------|
| system-design-specialist | Architecture grounding (modules/boundaries touched; root-cause for bugs) | /run pre-plan wave |
| database-specialist | Persistence grounding (tables/migrations/constraints) | /run pre-plan wave, when ticket touches data |
| frontend-specialist | UI grounding (framework/state/components) | /run pre-plan wave, when ticket touches UI |
| security-specialist | Threat-surface grounding (auth/input/sensitive data) | /run pre-plan wave, when ticket crosses a security boundary |
| testing-observability-specialist | Test/log/metric **gap** finding for planning (distinct from QA's verification role) | /run pre-plan wave |
| repro-specialist | Empirical reproduction (always for bug tickets; agent's own judgment otherwise); shares its procedure with `/fix` via the `repro` skill. A project skill or agent registered by `/setup-workspace` may replace it for a ticket when triage says so | /run pre-plan wave |

**Project maturity (`greenfield` vs. `brownfield`):** `pre-plan-triage` also classifies
`project_maturity` per ticket area — `brownfield` (default) when this area has existing
code/conventions to ground in, `greenfield` when it genuinely has none. This is a **second,
orthogonal axis** to which specialists are routed: it does not add agents, it switches each
routed specialist's **mode** between "ground in what exists" (brownfield) and "propose the
baseline convention for this area" (greenfield, a one-time bootstrap, not the ticket's full
solution). Keeps the specialist catalog small instead of multiplying agents per project phase.

**Front-end personas (write-capable):**

| Name | Role | Used By |
|------|------|---------|
| prd | Product requirements analyzer | /prd command |
| spectech | Technical specification designer | /spectech command |
| tasks | Task breakdown specialist | /tasks command |

**Enterprise MCP specialists (read-only, optional/opt-in — not default pre-plan sources):**
`mcp-confluence`, `mcp-jira`, `mcp-glean` are only scheduled by `pre-plan-triage` when **both**
registered with `Access: yes` in `docs/workspace-tools.md` (via `/setup-workspace`) **and**
signaled by the ticket text — a fresh workspace schedules none of them by default, which is
correct, not degraded. `mcp-gitlab` is not a pre-plan source at all; it's invoked mid-run for
branch/MR metadata. Persona subagents must **not** call enterprise MCP tools directly; they emit
a `REQUEST_MAIN:` escalation with a specialist label and query, and the main loop runs the
matching `mcp-*` subagent and feeds the bounded result back.

> **Flat orchestration (a runtime constraint, not just a convention):** subagents cannot spawn
> further subagents. Only the **main conversation loop** schedules the next delegation — it invokes
> both persona subagents and the read-only helpers. A persona subagent that needs a helper, an MCP
> specialist, or a human decision returns an escalation line the main loop honors: `REQUEST_MAIN:`
> (run the named helper/`mcp-*` subagent), `QUESTION:` / `ASK_USER` (ask the user), or
> `APPROVAL_NEEDED:` (stop-for-approval). `/run` is likewise pure main-loop orchestration driven by
> the `run-pipeline` skill.

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
- **`--max-preplan-iterations N`:** override the pre-plan merge ↔ pre-plan-reviewer self-heal loop caps, before `Task(prd)` ever runs (default 3; independent of `--max-plan-iterations`)
- **`--pre-plan` / `--plan` / `--dev` / `--finish`:** mutually exclusive **checkpoint** flags — run normally (from the start, or `--resume`d) through the end of the named stage, then stop with `STAGE COMPLETE: <name>` instead of continuing (`--finish` is the non-early-stop case, ending in the normal `PIPELINE: COMPLETE`). Pass `--resume` on every staged invocation after the first for a ticket. See the `run-pipeline` skill — **Staged execution (checkpoint flags)**.
- **Escape hatches:** /fix (bugs), /do (quick tasks) — **Ticket-folder amendment:** re-run `/prd`/`/spectech`/`/tasks` over the existing folder with "changes"

**Branch gate timing (important, non-default from a naive reading):** branch awareness at the
start of `/run` is **informational only** — a soft prompt, not a hard stop — because the
PRD/Spectech/Tasks segment only writes the (gitignored) ticket folder, never the working repo.
Analyzing on the protected/default branch is fine, and often correct (it reflects production). The
**hard** protected-branch gate (abort / stay / create-and-approve-a-name) fires immediately before
the **first** implementation `Task(dev|sre|data)` — the first point the pipeline actually writes
product code. **Worktrees are opt-in only:** the default is a single checkout on whichever branch
that gate resolves; a `git worktree` is created only if the user explicitly asks for isolated/
parallel working copies. See the `run-pipeline` skill — **§1**, **§5 Pre-check — branch gate**.

**Reject invalid orchestration:** treat a `/run` as failed (do not report success) if you see `ORCHESTRATION_ABORTED`, single-agent implementation instead of `Task` delegations, `Skipped:` of the PRD/Spectech/Tasks segment/qa/summary/reviews without the matching `--skip`, a single `Task(dev|sre|data)` spanning multiple `### Phase N:` blocks, or a persona editing `tasks.md` checkboxes/`_state.json`/`status` before `Task(scrum)` PROCEED. Full list in the `run-pipeline` skill.

## Git and GitLab mutations (paramount)

- **Persona subagents must never** run `git commit`, `git push`, or mutating GitLab actions.
- **The orchestrator (main loop) must never** *silently* auto-push, auto-create/open an MR, or invoke mutating GitLab APIs — except the `/rebase` push below. It **may** perform these via the GitLab MCP after **explicit user confirmation** at that step (see below).
- **Exception — Finish / mid-pipeline commit:** the main loop may run commits **only** via
  **`scripts/hooks/pipeline-finish.sh`** (§9, after the user selects an offered message) and/or
  **`scripts/hooks/pipeline-commit.sh`** (mid-pipeline when ticket **`_state.json.commit_policy`**
  authorizes — see run-pipeline **Commit policy**). If the user chooses "do not commit" /
  "other-manual" at Finish, pass **`--no-commit`**. Never raw `git commit`. Mid-pipeline never pushes.
- **Push:** the main loop may run `git push` (including `--force-with-lease` when a confirmed history rewrite requires it) after an explicit user "Yes" to a push prompt. Never auto-push silently — except `/rebase`.
- **Exception — `/rebase`:** invoking `/rebase` **is** that consent. When a ticket key is given, checkout (or create a local tracking branch from an existing `origin` ref) without a second Yes — never invent a branch that does not exist on origin. After a clean rebase of a non-protected working branch, push with `git push --force-with-lease` (or `git push -u` when there is no upstream). Do not ask for a second Yes. Do not push on conflict, dirty-tree skip, failed pull, or when the current branch is the main/default. Never `--force` / `-f` without lease. Never push to `main` / `master` / `develop` / `development` / `release/*`.
- Each branch creation and each mutating GitLab action (MR create/update, write API) requires **explicit user confirmation at that step** — except `/rebase` creating a local branch that already exists on `origin`. Once confirmed, the main loop performs MR create/update via the GitLab MCP, always presenting the MR title/body for review first. See `scripts/tools/mr-description-from-spec.sh` for body content. `/rebase` (multi-repo git-sync) never creates or updates an MR via GitLab API and never transitions a Jira ticket.
- GitLab operations use the **GitLab MCP** as the primary tool, run only after the user confirms. `glab` is **not** used in this workspace (not authenticated); do not suggest it.

## Confidence Scoring

- Per-persona reviewers emit 0–100% scores including spec alignment
- /scrum (PO/SM/PM) evaluates at each gate with business judgment
- **≥ threshold (default 90%):** PROCEED
- **Below threshold, first miss:** REWORK (automatic)
- **Below threshold after at least one rework:** ASK_USER
- **Max loops hit:** ESCALATE
- /scrum may override defaults when business context warrants
- Threshold is per-gate; document overrides in the ticket folder or session notes when non-default
- If domains differ in risk, define per-domain weights or minimums in `spectech.md`

## Spec Format (ticket-folder contract)

This section is the **single source of truth** for the `_state.json`/`_notes.md` control-file
contract — every piece that touches a ticket folder reads this instead of re-describing the
schema.

- **Path/naming convention:** `docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/` (with Jira key) or
  `docs/specs/{YYYY-MM-DD}-{slug}/` (without key) — one folder per ticket, date-prefixed, with a
  short kebab-case slug. If a step needs to create the folder, it uses this convention.
- **Control files:** `_state.json` (machine-readable) + `_notes.md` (human-readable running log).
  **`context.json` is never created.**
- **AC-1 regression guard:** any step that finds both `context.json` and `_state.json` in the same
  folder must stop and surface the collision — never silently prefer one.
- **`_state.json` schema:** `ticket_key` (or `null` when there is none), `slug`, `repo`/`branch`
  (multi-repo, when applicable), `commit_policy` (see **Git and GitLab mutations**), and `steps` —
  an **open** string-keyed map: the required orchestrator's six keys (`prd`, `spectech`, `tasks`,
  `implement`, `code_review`, `summary`), or a standalone piece's own key (e.g. `ticket_intake`,
  `impact_analysis`, `repro`, `flowchart_check`, `build_test`, `proof`). Step values: `pending |
  in_progress | done | blocked | skipped`.
- **`_notes.md` — Auditability convention:** append-only running log; one entry per state-changing
  step (timestamp, acting persona/step, decision or outcome, and where to resume). Every step that
  updates `_state.json` appends a matching `_notes.md` entry.
- **Stop-gate / HITL rules:** a persona blocked on a genuine question or a low-confidence decision
  surfaces it via `QUESTION:` / `ASK_USER` / `APPROVAL_NEEDED:` (see **Flat orchestration** above)
  and records the gate in `_notes.md` rather than guessing.
- `prd.md`, `spectech.md`, `tasks.md` — three separate files (never merged); `spectech.md`'s frontmatter declares `profile: lean|standard|full`.
- Domain tags on `tasks.md` checkboxes: `[dev]`, `[sre]`, `[data]`; multi-repo: `[dev:repo]`
- Phases for cross-repo dependencies
- Shorthand: full folder path, slug match, `latest`, or a Jira key that resolves to/creates a folder

## Multi-Repo

- Target repos are cloned as subdirectories of the workspace root; `/clone` excludes each one from
  this workspace's own history by appending a `.gitignore` entry (they are their own git repos —
  never tracked as part of the workspace)
- Add one with **`/clone <git-url> [target-dir]`** — clones into the root and registers it in the inventory
- The inventory (repo name + current branch) is detected dynamically and injected into context on session start — no need to list repos manually
- Scope tables in specs list involved repos
- `[domain:repo]` task tags
- Phases order dependencies
- Within phases: parallel. Between phases: sequential.
- Single-repo work: omit `:repo` tags; scope table may list one repo only
- `/rebase` (standalone skill): empty `/rebase` infers at most one ticket from **this conversation**,
  then rebases the child repo(s) that ticket actually changed (fallback: that ticket's
  `_state.json` `repo`/`branch`). Otherwise it iterates every child repo (current branch).
  `/kb-refresh` iterates every child repo directly, independent of any ticket folder.

## Knowledge Base

**Per-ticket grounding comes from the pre-plan domain specialists** (`system-design-specialist`,
`database-specialist`, `frontend-specialist`, `security-specialist`,
`testing-observability-specialist`) — always available, no MCP, no setup, read the current code
on demand for every ticket. The local `/kb` knowledge base below is a **separate, optional**
mechanism for **persistent, cross-ticket** context (architecture overview, conventions) that
doesn't change per ticket — it complements, not replaces, the domain specialists.

Structured project context at `knowledge/{project-name}/` (tracked in git, shared across the team).
- Folder per project: `_index.md` (always loaded, ~50 lines) + section files loaded on demand (architecture, api, data-models, dependencies, infrastructure, conventions)
- Built by `/kb <target-dir>` — optional, somewhat expensive, manual, full-rebuild-per-project. Run on first onboarding or after major restructuring.
- **Incremental, multi-repo-aware refresh:** `/kb-refresh` (standalone) — for every child repo, pulls the main branch and diff-classifies what changed to decide which `knowledge/{project}/` need updating; distinct from `/kb`'s manual full rebuild.
- **Cross-repo, system-level view:** `/kb-concentrator` (standalone) — maintains `knowledge/global-kb/`, the aggregated view of how projects call into each other (end-to-end flows, integration boundaries). Typically chained after `/kb-refresh`.
- Consumed by `/prd` (loads index + relevant sections, falls back to codebase-explorer if KB absent)
- `/run` warns if KB is missing but does **not** auto-invoke `/kb`

## Skills

Framework skills ship under `agentic/skills/` (installed per-IDE — see your adapter file for exact
paths). Optional project-specific skills (if a team adds any) are kept outside `agentic/`
and must never be required by a core SDD persona or by the required orchestrator. Setup does
not copy or link them.

- **run-pipeline** — /run (the authoritative end-to-end orchestration workflow the main loop follows — PRD/Spectech/Tasks segment → implement → review → QA → summary)
- **generate-prd** / **generate-spectech** / **generate-tasks** — the `/prd`/`/spectech`/`/tasks` personas' normative document templates, adapted to read/write `_state.json`+`_notes.md`
- **prd-validator** / **prd-discovery** — supporting skills for `/prd` (implicit-requirements/scope validation; brainstorm phase), adapted to the same control-file contract
- **generate-spec** — retained only as a reference for `plan-reviewer.md`'s single-file-mode completeness check (unchanged persona, FR-7); nothing in this repo produces single-file specs anymore
- **spectech-analyzer** — /spectech (reuses pre-plan domain specialist briefs before re-scanning the codebase; combines test-harness-analyzer + architecture-detailer)
- **repro** — shared reproduce-the-symptom procedure, used by both `/fix` and the pre-plan `repro-specialist` so there is one implementation, not two
- **review-report** — /qa (structured QA + security narrative)
- **deploy-checklist** — /sre (CI/CD coverage checklist, 5-tier: dev/qa/int/sbx/prd)
- **confidence-scoring** — reviewers + /scrum (per-domain weights, sub-scores, trend analysis, calibration)
- **knowledge-base** — /kb (output structure; optional and infrequent — the per-ticket pre-plan domain specialists cover most day-to-day grounding needs without it)
- **kb-refresh** / **kb-concentrator** — standalone, incremental multi-repo KB tooling (see Knowledge Base above); thin utility commands, same shape as `/clone`
- **clone** / **rebase** / **setup-workspace** — workspace utilities (child-repo clone; multi-repo git-sync; MCP tool registry)

## Hooks (what exists and why)

Exact event names, matchers, and script locations are IDE-specific — see your adapter file. The
**set of hooks and their purpose** is shared:

| Hook | Purpose |
|------|---------|
| format-on-edit | Auto-format edited files with the project formatter |
| session-init | Inject child-repo inventory + spec status + session memory at session start |
| audit-log | Append a session record to the local audit log |
| session-verify | Verify no uncommitted secrets, hook health, spec inconsistencies |
| before-shell | Block dangerous commands (`rm -rf`, destructive SQL, force-push to protected branches) |
| before-read | Block reading `.env`, credentials, private keys, secrets files |
| subagent-gate | Block writes when the target's child repo is on a protected branch (`main`/`master`/`develop`/`release/*`); workspace root is excluded |

Hooks fail-open: failures log but don't block. `subagent-gate` has no override — writes to
protected branches are always refused.

## Session Memory

Ephemeral scratch per session at `docs/sessions/<session-id>/current.md` (gitignored). The active `session-id` is stored in `docs/sessions/ACTIVE_SESSION`.
- Read: `scripts/tools/session-memory.sh read`
- Write: `scripts/tools/session-memory.sh write "DECISION: chose PostgreSQL for sessions"`
- Clear: `scripts/tools/session-memory.sh clear`
- Categories: DECISION, QUESTION, GATE, or free-form context. Optional post-`/run` audit lines (human only): `COMMIT_SUGGESTIONS:`, `PUSH_CONFIRMED:`, `MR_TARGET_BRANCH:`, `MR_CONFIRMED:`.
- Injected into context on session start via the `session-init` hook (includes the active session id + path).
- **Cleanup:** stale session files (untouched >24h) are deleted at next session start; empty session dirs may be removed afterward. Not a timer — only pruned when a new session begins.
- **Two-layer state:** this is the ephemeral, cross-session-agnostic **orchestration-run** checkpoint (crash-resume for one `/run`). It is separate from — and does not replace — each ticket's own persistent `_state.json`/`_notes.md`, which is the per-ticket, cross-session audit trail (see **Spec Format** above). Not a database. Not a replacement for the ticket folder.

> **Note:** this section is under active reconsideration — see
> `myDocs/specs/2026-10-06-eliminate-sessions-ticket-scoped-state.md`. Until that migration lands,
> it reflects current behavior.

## Metrics

Local-only pipeline and agent metrics: `scripts/tools/metrics.sh [overview|agents|specs|gates|sessions|models|cost|export|budget-check]`.
Aggregates data from `docs/audit.log`, `docs/sessions/`, and optional `docs/usage-events.tsv`. Nothing leaves the machine.

## MCP

Servers are configured per-IDE (see your adapter file); teams add or remove them as needed. All personas work without MCP — it is never required for the core flow.

Enterprise MCP access is **mediated through the read-only `mcp-*` specialist subagents** (`mcp-confluence`, `mcp-gitlab`, `mcp-jira`, `mcp-glean`), scheduled only by the main loop. Persona subagents never call enterprise MCP tools directly; they escalate with `REQUEST_MAIN: <specialist> <query>` and the main loop runs the matching specialist. `mcp-confluence`/`mcp-jira`/`mcp-glean` are **optional, opt-in** pre-plan sources (registered via `/setup-workspace`, gated by `pre-plan-triage` — see **Pipeline**); `mcp-gitlab` is used mid-run for branch/MR metadata, not as a pre-plan source.

## Error Protocol

1. **Missing arguments:** ask user; show expected syntax
2. **Ticket folder not found:** search `docs/specs/` for matches; suggest `/prd <new-folder>` or `/run <JIRA-KEY>`
3. **Target dir not found:** list dirs; ask confirmation
4. **Tool failure (non-zero exit):** show error, explain, suggest fix; never silently proceed
5. **MCP unavailable:** warn; continue; degrade gracefully
6. **Ambiguous intent:** one clarifying question
7. **Scope creep:** stop; recommend a `/prd` amendment (re-run `/prd` over the existing ticket folder)
8. **Hook failure:** fail-open; log; do not block
9. **Orchestration failure:** /run stops and reports; QA loops capped at 3; review loops at 2; surface last step and suggested next action
10. **Reviewer override:** log actor, reason, and prior score for audit trail
11. **Two control files detected (`context.json` + `_state.json`):** stop and surface the collision — never silently prefer one (AC-1 regression guard, per **Spec Format** above)
