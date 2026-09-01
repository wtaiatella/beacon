---
name: run-pipeline
description: "Orchestrates the full BMAD+SDD pipeline when the user invokes /run — branch consent, worktrees, Task delegations to personas, gates, QA, summary. Use when the user runs /run with target dirs or a spec and optional flags."
disable-model-invocation: true
---

# Run pipeline (orchestrated mode)

You are the **main session agent** executing this skill. There is **no** `/run` subagent and **no** `run-exec` relay.

> **Claude Code execution model:** the **main conversation loop is the orchestrator** — you. Everything below that says "the main agent", "the main session", "you are the orchestrator", or schedules **`Task(...)`** refers to this main loop. You delegate to persona and helper **subagents** through the **Task tool** (`Task(prd)`, `Task(dev)`, `Task(security-scanner)`, etc.). Claude Code subagents **cannot spawn their own subagents**, so **only the main session** ever schedules **`Task(...)`** — which is exactly what this skill's **flat orchestration** requires. The rule "personas must not nest `Task(...)`" is therefore both a design constraint of this skill **and** a hard property of the Claude Code runtime; the two align directly. Keep all step numbers (§ 1–§ 9), gates, and non‑negotiables below intact.

## Non‑negotiables

1. **Orchestrate only** — Implement pipeline steps via **`Task`** to personas (`plan`, `dev`, `sre`, `data`, `qa`, `summary`, `scrum`, reviewers, etc.). Do **not** perform **ad-hoc** repository edits, arbitrary shell scripts, or mechanical multi-step fixes yourself — delegate **`Task(do)`** for those. **Exceptions:** **§ 9 Finish** mutations via **`scripts/hooks/pipeline-finish.sh`** after user consent (commit message selection; **push** only when passed **`--push true`** matching explicit **Yes** to the Finish push prompt); **mid-pipeline** commits via **`scripts/hooks/pipeline-commit.sh`** when **`commit_policy`** authorizes (**Commit policy**); **worktree** and **user-approved** branch **`git`** flows per **Non‑negotiables** item **10**, **enumerated** paths in **Scripts you may invoke via Shell**, and **§ 9** **multi-root detach** (remove **only** **`docs/sessions/<session-id>/session.code-workspace`** after explicit **Yes** — see **§ 9** — **Multi-root detach** and **Non‑negotiables** item **10**). Do **not** implement product code, specs, or reviews yourself in this thread outside those exceptions.
2. **No fake completion** — Do not emit `PIPELINE: COMPLETE` unless every required step for the chosen mode actually ran via Task (or was explicitly skipped with user `--skip` flags).
3. **Branch consent** — Never create a branch without **explicit user approval** of the name. Suggest a name; wait for confirmation or abort.
4. **Worktrees** — Create worktrees in the **working repo** (the app repo or target repo that will change), not only in the framework repo, when isolating AI work. Pass `WORKTREE_PATHS: { "repo-name": "/path/to/worktree" }` in Task prompts so subagents use `working_directory` correctly. **Multi-root attach** (**`attach-target.txt`** / **`session.code-workspace`** — see **§ 1**): when **`docs/sessions/<session-id>/attach-target.txt`** exists, the **working repo** for implementation and worktrees is the **target** clone — set each **`Task(dev|sre|data)`** **`working_directory`** to that **target root**; use **`WORKTREE_PATHS`** only for worktree paths **inside** the target repo. Framework scripts (`session-memory.sh`, `apply-models.sh`) run from the **orchestrator** workspace root unless a script says otherwise.
5. **Human approval before apply** — After the pipeline, present results; do **not** merge or “apply” worktree changes without the user confirming, except (a) **`scripts/hooks/pipeline-finish.sh`** with **`--commit-message`** / **`--commit-file`** in **§ 9 Finish** when the user **explicitly chooses** a suggested commit message, and **`--push true`** only when the user **explicitly answers Yes** to the Finish push prompt (`AskQuestion` or chat fallback); and (b) **mid-pipeline** **`scripts/hooks/pipeline-commit.sh`** when **`_state.json.commit_policy`** authorizes it (**Commit policy** below) — never push from mid-pipeline.
6. **Git / GitLab boundaries** — The orchestrator **never** runs **`git push`** **except** via **`pipeline-finish.sh --push true`** in **§ 9 Finish** after the user’s **explicit Yes** to push (same **working repo** / branch semantics as commit). The orchestrator **never** auto-pushes or runs push outside **§ 9**. Branch create/switch only per **user-approved** flows and worktrees above. **`git commit`** runs **only** through **`pipeline-finish.sh`** (**§ 9 Finish**) and/or **`pipeline-commit.sh`** (mid-pipeline when **`commit_policy.mode`** is **`per_task`** / **`per_phase`** and consent covers that commit — see **Commit policy**). **Never** raw **`git commit`** in Shell. If Finish chooses **do not commit** / **Other (manual)**, pass **`--no-commit`**. MR create/update is performed by the orchestrator **via the GitLab MCP** (`mcp__GitLab__*`) only after **explicit user confirmation** of that step, always presenting the MR title/body for review first — never silently (see **`CLAUDE.md`** — Git and GitLab mutations).
7. **§ 6 mandatory after each § 5 batch** — When **§ 5** implementation **`Task(dev|sre|data)`** completes for a **phase** (or for the **single implicit phase** if the spec has no `### Phase N:` headings), you **must** run **§ 6** — **parallel** domain **`*-reviewer`** (as needed) **and** **`Task(security-scanner)`** scoped to **`phase-impl-delta`** (see **§ 6 Implementation review**), **then** **`Task(scrum)`** — **before** **§ 7 QA**, **§ 9 Finish**, or the **next** phase’s **§ 5**. **Never** chain the next phase’s **§ 5** without **§ 6** after the prior phase; **never** jump from **§ 5** to **§ 7**/**Finish** without **§ 6** when there is only one phase. **Never** one implementation **`Task`** whose prompt covers **more than one** **`### Phase N:`** block. **Exception:** **`--skip impl-review`** skips the **entire** § 6 wave (reviewers, **`Task(security-scanner)`**, § 6 **`Task(scrum)`**) — see **`--skip impl-review`** under **Parsed inputs** and **Invalid completion**.
8. **No direct Markdown edits for pipeline bookkeeping** — The main session **must not** use **`apply_patch`**, bulk search-replace, or equivalent to edit **`*.md`** for spec task checkboxes, **`status`**, **`last-updated`**, or other pipeline bookkeeping—except **Finish** steps where this skill already allows (**`pipeline-finish.sh`** per **§ 9**). Updates authorized after **`Task(scrum)`** **PROCEED** belong in **`Task(do)`** only (see **Task(do) for authorized spec updates** under **Scrum authority and spec `status`**).
9. **No backward-compat symlinks for session layout** — **Never** create symlinks under **`docs/sessions/<session-id>/`** (or elsewhere in-repo) to preserve old paths when artifact directories move or are renamed. Policy is **hard cutover:** update **`session-memory.sh`**, orchestrator behavior, **`.claude/`** agents, **`scripts/`**, **`docs/`**, and every consumer to the **canonical** trees only — **`docs/sessions/<session-id>/artifacts/...`** (e.g. **`artifacts/explorer/`**, **`artifacts/scanners/`**). Do **not** add session-root aliases such as **`exploration`** → **`artifacts/explorer`** or **`qa-artifacts`** → **`artifacts/scanners`**; **`session-memory.sh`** creates real directories under **`artifacts/*`** and does **not** maintain those symlinks.
10. **No raw shell (orchestrator allowlist)** — The main session **must not** chain Shell commands with **`&&`**, **`||`**, or **`;`**. **Do not** use inline **`python3 -c`**, ad-hoc **`grep`** / **`test`** one-liners for orchestration probes, or raw **`git`** for read-only inspection, **`status`**, **`diff`**, or **`add` / `commit` / `push`**. Use the scripts below (one invocation per step from workspace root unless noted). **`scripts/hooks/pipeline-finish.sh`** always runs **`python3 scripts/tools/audit-session-trace.py`** internally — **do not** invoke that Python entry point separately after Finish. Mid-pipeline commits use **`scripts/hooks/pipeline-commit.sh`** only (no audit, no push).

    **§ 9 multi-root detach (narrow exception):** After **`pipeline-finish.sh`** and after explicit **Yes** to **§ 9** — **Multi-root detach** (`AskQuestion` or chat fallback), the orchestrator may run **exactly one** **`rm`** Shell invocation with **one** argument: the workspace-relative path **`docs/sessions/<active-session-id>/session.code-workspace`** (resolve **`<active-session-id>`** from **`docs/sessions/ACTIVE_SESSION`**), **only** if that file exists. **Do not** use **`rm`** for any other path; **do not** chain **`rm`** with other commands. Prefer **`scripts/tools/session-memory.sh detach-workspace`** (single invocation) when available; **`rm`** remains the documented fallback.

    **Allowed Shell paths (normative):**
    - **`scripts/hooks/pipeline-init.sh`** — **§ 2 Init** (session rotation, trace anchors, **`apply-models.sh --snapshot`**, session-memory read, optional knowledge warning). Flags: **`--resume`**, optional **`--slug`**, optional **`--targets`** (repeatable dirs for **`knowledge/<dir>/_index.md`**).
    - **`scripts/tools/git-inspect.sh`** — **§ 1** read-only repo summary (**branch**, status, diff stats). Default: orchestrator repo at workspace root; **`--repo <path>`** inspects another git working tree (writable **target** clone for branch consent when multi-root attach is active).
    - **`scripts/tools/log-gate.sh`** — **`GATE:`**, **`impl | …`**, **`impl-review | …`**, **`FAILURE:`**, **`MANUAL_GATE_CONTEXT:`** lines (prefer over spelling the same strings as raw **`session-memory.sh write`**).
    - **`scripts/hooks/pipeline-finish.sh`** — **§ 9** only: optional **`git add` / `git commit` / `git push`** via flags after user consent, then session trace audit. See **`--help`** for **`--no-commit`**, **`--commit-message`**, **`--commit-file`**, **`--push true|false`**, **`--pre-audit-delay-seconds`**.
    - **`scripts/hooks/pipeline-commit.sh`** — mid-pipeline **`git add` / `git commit`** only when **`commit_policy`** authorizes (**Commit policy**). **Never** push. **Never** audit. See **`--help`**.
    - **`scripts/tools/session-memory.sh`** — **`read`**, **`write`** for lines **not** covered by **`log-gate.sh`** (e.g. **`PLAN_REVIEW_FEEDBACK:`**, **`EXPLORATION:`**, **`PIPELINE: COMPLETE`**, optional Finish audit lines, multi-root **`WORKSPACE_DETACHED:`** / **`DETACH_CONFIRMED:`**, **`COMMIT_POLICY:`**). **`detach-workspace`** — **§ 9** only: remove **`session.code-workspace`** for the active session in **one** invocation. Do **not** duplicate Init subcommands already inside **`pipeline-init.sh`**.
    - **`scripts/tools/apply-models.sh`** — Per **Model plan** for dynamic per-step overrides **after** Init (Init snapshot is already inside **`pipeline-init.sh`**).
    - **`scripts/tools/session-handoff.sh`** — Pre-plan writes under **`pre-plan/`** (merged brief, specialists).
    - **`scripts/tools/mr-description-from-spec.sh`**, and when referenced in this skill: **`scripts/tools/spec-status.sh`**, **`scripts/tools/git-diff-summary.sh`** (typically **inside** **`Task(summary)`**, not as orchestrator bulk input).

    **`git` in Shell (narrow exceptions):** **`git worktree add`**, **`git checkout -b`** / branch switch **only** with **user-approved** branch names per **§ 1**, or other **explicit** user-requested git operations **not** implemented above. **Never** raw **`git push`**, **`git commit`**, or **`git status`** / **`git diff`** for orchestrator probes — use **`pipeline-finish.sh`**, **`pipeline-commit.sh`**, and **`git-inspect.sh`**.

## Anti‑patterns (do not do these)

- Use `Task(run, …)` — the `run` agent does not exist.
- For **`/run`**, delegate pre-plan **`Task(mcp-*)`** only from the **main session** during **Pre-plan context (optional MCP)** (or a later orchestrator merge), not nested inside **`Task(prd)`** / **`Task(dev)`** for bounded MCP gather. **Staged waves:** **Wave 1** runs **`Task(mcp-glean)`** and **`Task(mcp-arc)`** in parallel **only** when triage lists them; **Wave 2** runs **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`** **only** after **merge + gate** (see **Pre-plan context**). Do **not** fan out all five specialists in one parallel batch by default. **Flat** orchestration only (main session); do **not** nest **`Task(mcp-arc)`** inside **`Task(prd)`**. **ARC — two lanes:** **(A)** Pre-plan Wave 1 (**`Task(mcp-arc)`**) from the main session when triage lists ARC. **(B)** **In-session** ARC tool calls are for **standalone** **`/prd`** (and **`/kb`** where applicable), **not** for **`/dev`** or **`/fix`** under orchestrated **`/run`** — implementers return **`REQUEST_MAIN: ARC …`**; the orchestrator runs **`Task(mcp-arc)`** and persists under **`pre-plan/specialists/`** (see **§ 5** — **Mid-run enterprise context**, **Pre-plan context**). **Mid-run** enterprise fetch for any specialist follows the same **main-session-only** rule — **do not** nest **`Task(mcp-*)`** inside personas.
- Skip the **PRD/Spectech/Tasks segment** (**`Task(prd)`**→**`Task(spectech)`**→**`Task(tasks)`**) / **`Task(qa)`** / **`Task(summary)`** unless the user passed the matching **`--skip`** flag (**`--skip plan`** for the front-end segment — flag name unchanged; see **§3-4**).
- Run **§ 7.0** (**QA prep wave** — **`Task(spec-validator)`** + **`Task(security-scanner)`** → **`artifacts/scanners/`**) whenever **`Task(qa)`** runs **without** **`--skip qa`**; skipping **§ 7.0** while still running **`Task(qa)`** **without** **`--skip qa`** is **orchestration failure** (see **Invalid completion**).
- Fill in “N/A” for all scores and models to pretend the pipeline ran.
- Read large specs or code yourself to “save tokens” before delegating — personas do discovery; you only coordinate (you may read **session memory** and **script output**).
- **Chaining implementation `Task` for the next phase without completing § 6 for the current phase** — invalid; **§ 6** (**parallel** domain **`*-reviewer`** and **`Task(security-scanner)`** with persisted **`phase-<N>-security.md`**, **then** **`Task(scrum)`** — when not **`--skip impl-review`**; see **§ 6 Implementation review**) must run **after** each phase’s **§ 5** and **before** the next phase’s **§ 5**.
- **`Task(dev)`** (or **`Task(sre)`** / **`Task(data)`**) whose prompt covers **more than one** **`### Phase N:`** block — **never**; at most **one** phase per implementation **`Task`**.
- **Nested `Task` from personas** — **`Task(prd)`**, **`Task(spectech)`**, **`Task(tasks)`**, **`Task(dev)`**, **`Task(qa)`**, reviewers, etc. **must not** invoke **`Task(...)`** to another agent. Only the **main session** orchestrator delegates **`Task`**; personas **escalate** with **`QUESTION:`** / **`APPROVAL_NEEDED:`** (orchestrator may **`AskQuestion`** the user or append to **`docs/sessions/<id>/current.md`** — see **Escalation and user prompts**).

**Maintainers (nested Task / persona docs):** **`docs/reference/nested-task-audit.md`** — audit, decision table (explorer, validators), and per-agent remediation. Spec: **`docs/specs/2026-04-10-road-36-nested-task-subagent-audit-spec.md`**. Keep this skill as orchestration source of truth; **ARC lane B** (**`/prd`**, optional **`/kb`**) does **not** extend to **`/dev`** / **`/fix`** under orchestrated **`/run`** — use **`REQUEST_MAIN: ARC …`** → **`Task(mcp-arc)`** (see **Pre-plan context**, **§ 5** — **Mid-run enterprise context**). Spec: **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`**.

## Parsed inputs

From the user’s `/run` line, extract:

- **Targets:** a **ticket-folder path** or a **Jira key** — never a single-file `spec.md` path (FR-4, FR-5, AC-6):
  - **Ticket folder:** `docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/` (with Jira key) or `docs/specs/{YYYY-MM-DD}-{slug}/` (without key) — folder containing `prd.md`, `spectech.md`, `tasks.md`, `_state.json`, `_notes.md` (see the `bcs-ticket-workflow` skill).
  - **Jira key:** e.g. `BG-10965` — resolves to an existing ticket folder (matched via `_state.json.ticket`) or scaffolds a new one; see **Ticket-folder resolution (Jira-key primary argument)** below.
  - **Shorthand:** slug match (finds the folder), `latest` (most recent).
  - Single-file `spec.md` paths and bare target-directory discovery for a spec-authoring persona are **not** accepted — the required orchestrator's front end is always **`Task(prd)`**→**`Task(spectech)`**→**`Task(tasks)`** (FR-3); there is no `Task(plan)` and no `/plan` in this orchestrator (FR-4).
- **Goal text:** remainder after targets/flags.
- **Flags:** `--confidence N` (default 75), `--review`, `--manual` (**manual step gates** — orchestration pauses after plan and after each domain track; **not** **manual model assignment** from **`.claude/models.user.yml`**), `--resume`, `--skip <step>`, **`--skip impl-review`** (optional **escape hatch** — skips **§ 6** implementation review; see below), `--branch [name]` (optional hint only; see **Branch naming** below), **`--max-iterations N`** (caps **§ 6** / implementation rework loops and similar — default **3** when unset), **`--max-plan-iterations N`** (caps **§ 4** plan ↔ plan-reviewer self-heal only — default **3** when unset; independent of **`--max-iterations`**), `--model-strategy conservative|balanced|quality`, `--budget $N`.
### Ticket-folder resolution (Jira-key primary argument)

Implements spectech's **D8**. When the primary argument matches a Jira-key pattern (`[A-Z]+-[0-9]+`) rather than an existing folder path:

1. Search `docs/specs/*/_state.json` for a `.ticket` field matching the key.
2. **If found:** use that folder — proceed to **§3-4** using the existing `_state.json`/`_notes.md`.
3. **If not found:** create the folder scaffold `docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/` (date = today, `{TICKET-KEY}` is the Jira key as-is e.g. `BG-10965`, slug is a short kebab-case description derived from the key) with a bare `_state.json` (ticket key set, `steps` empty) + `_notes.md` (per the `bcs-ticket-workflow` skill), then proceed to **§3-4** with the Jira key passed through as context to `Task(prd)`.
4. **Does not** run project-specific intake/repro tools — FR-10 is explicit that optional
   project overlays are not wired into the required orchestrator. If the ticket folder is not
   ready yet, scaffold it here (or the user prepares it first), then proceed with
   `Task(prd)`→`Task(spectech)`→`Task(tasks)`.

### Ticket-folder validation

When the primary argument is a **folder path** (`docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/` or `docs/specs/{YYYY-MM-DD}-{slug}/`):

1. **Validate folder exists** — if not, ask user: create new or abort.
2. **Check for files in order:** `tasks.md` → `spectech.md` → `prd.md` → check `_state.json.current_step` / `.steps` for workflow status (see the `bcs-ticket-workflow` skill for the schema).
3. **Determine entry point:** resume at the first `pending` / `in_progress` / `blocked` step among `prd` → `spectech` → `tasks` (in that order) per `_state.json.steps`; if all three are `done`, proceed directly to **§5 Implementation**.
4. **Two-control-file regression guard (AC-1):** if both `context.json` and `_state.json` are found in the folder, stop and surface the collision (per `bcs-ticket-workflow`'s guard) rather than picking one silently.
5. **Pass to `Task(prd)`** (or whichever of `Task(prd)`/`Task(spectech)`/`Task(tasks)` resumes per step 3): the **folder path**, plus which of `prd.md`/`spectech.md`/`tasks.md` already exist and their `_state.json.steps` status.

Steps not listed in `--skip` are **required** for a valid completion.

- **`--skip plan`:** Skips **Pre-plan context (optional MCP)** and **§3 PRD/Spectech/Tasks segment** (`Task(prd)`→`Task(spectech)`→`Task(tasks)`). **§ 2 Init** (model snapshot, session memory, etc.) **still runs** unless your orchestrator documents otherwise — do not read this as skipping all of Init. Pre-plan is tied to this front-end segment. Flag name is unchanged from the prior single-artifact `Task(plan)` design — only the content of what is skipped changes (three artifacts + folder-mode review instead of one artifact).
- **`--skip impl-review`:** Skips the **entire** **§ 6 Implementation review** wave — domain **`*-reviewer`**, **`Task(security-scanner)`** (phase **`phase-impl-delta`**), **and** § 6 **`Task(scrum)`** for implementation gates. **No** **`phase-<N>-security.md`** is produced or required. **Escape hatch only** — use when the user explicitly opts in. Emitting **`PIPELINE: COMPLETE`** after **skipping § 6** **without** this flag (or user-equivalent explicit skip) is **invalid completion**. Skipping **§ 6 between phases** without the flag is **orchestration failure** (phased specs require **§ 6 per phase** unless explicitly skipped by flag and documented).
  - **If `--skip impl-review` is set:** There is no **`Task(scrum)` PROCEED** to authorize **Proposed completions** from **`Task(dev|sre|data)`**. The main session **must not** silently apply spec checkboxes (**no** direct **`apply_patch`** on **`docs/specs/...`**) — either leave the spec unchanged, obtain **explicit user confirmation** before delegating **`Task(do)`** or other edits to task **`[x]`** / **`status`**, or record **`IMPL_REVIEW_SKIPPED:`** in session memory and label **Completion output** as **degraded** (implementation ran; gates skipped).

### Branch naming (`--branch`)

When suggesting a new branch name (especially after **branch consent** on a protected branch), **prefer** tying the name to the active spec:

| Kind | Suggested pattern | Example |
|------|-------------------|---------|
| Feature work | `feature/{spec-slug}` | `feature/gitlab-integration` |
| Hotfix | `hotfix/{spec-slug}` | `hotfix/acme-auth-timeout` |

Derive **`{spec-slug}`** from the ticket-folder name: strip `docs/specs/`, the date prefix `YYYY-MM-DD-`, and the ticket-key prefix `{TICKET-KEY}-` when present (or use the folder's shorthand slug). If **`--branch foo`** is present, treat **`foo`** as the primary suggestion but still obtain **explicit user approval** before any `git checkout -b` / branch create — same as today.

## Manual step gates (`--manual`)

**Naming:** **Manual model assignment** (`use_manual_models` in `.claude/models.user.yml`) is unrelated to the **`--manual`** flag on **`/run`**. **`--manual`** here means **manual step gates** (orchestration pauses only). They are **independent** — see **§ 2 Init** and **Model plan**.

**Optional MCP:** GitLab, Atlassian, and Glean integrations (**`.mcp.json`**) do **not** alter **`--manual`** pause points; if MCP tools are absent, personas continue with local tools only (**`CLAUDE.md`**).

### When active

The user passed **`--manual`** on the `/run` line. Set orchestration state **`manual_step_gates: true`** (conceptual; may be recorded in session memory for `--resume`).

### Default `/run` vs `--manual` (implementation shape)

- **Without `--manual` (default):** **§ 5–§ 6** per spec **phase** (see **§ 5**): within each phase, run **`Task(dev)`**, **`Task(sre)`**, **`Task(data)`** **in parallel** when the spec allows multiple domains; then **parallel** domain reviewers as needed, **batched** **`Task(scrum)`** with combined context for **that phase** (**§ 6**). **Before** the next phase’s **§ 5**, finish **§ 6** for the current phase.
- **With `--manual`:** Run **domain tracks sequentially** in spec order (typically **dev → sre → data** as tags dictate) **within each phase**. For **each** track the spec requires (skip omitted domains): **`Task(dev|sre|data)`** → matching **`Task(dev-reviewer|sre-reviewer|data-reviewer)`** → **`Task(scrum)`** for **that segment only** → **manual gate** (below) → then the next track **in the same phase**, or — when that phase’s tracks are done — **§ 5** for the **next** **`### Phase`**, or **§ 7 QA** if all phases are complete. Do **not** parallelize implementation or batch impl-review across tracks in this mode.

### Pause points

1. **Gate 1 — after the plan segment:** After the **§ 3–4** plan segment completes (**plan ↔ plan-reviewer** self-heal as needed, then **`Task(scrum)`** for the plan gate), **do not** start implementation until the user answers the **manual gate** prompt.
2. **Gate 2+ — after each domain track:** After **`(dev|sre|data)`** + matching **`*-reviewer`** + **`Task(scrum)`** for that segment complete, **pause** with the same manual-gate pattern **before** starting the next segment or **§ 7 QA** (skip tracks/reviewers the spec does not need).

### Each manual gate — `AskQuestion` (and chat fallback)

Prefer **`AskQuestion`** with three options (same product caveat as **§ 9 Finish**). If **`AskQuestion`** is unavailable, use **numbered chat options** (1 / 2 / 3) with the same labels:

1. **Proceed** — Continue to the next pipeline step (next track, QA, or downstream per order).
2. **Force review** — Re-run **only** the **immediately preceding review step** for this segment: **`Task(plan-reviewer)`** after the plan segment (gate 1), or **`Task(dev-reviewer)`** / **`Task(sre-reviewer)`** / **`Task(data-reviewer)`** after the corresponding implementation track. Then re-run **`Task(scrum)`** for **that same segment** (required before offering the manual gate again or proceeding). After that, **offer the manual gate again** unless the user already chose **Proceed** in a follow-up turn.
3. **Add context and review** — Append the user’s free text via **`scripts/tools/log-gate.sh manual-gate-context <segment> <user text...>`** (same line shape as **`MANUAL_GATE_CONTEXT: <segment> | <user text>`** under **`## Timeline`** in **`current.md`**). **Order of re-runs:** inject that line into the **next** delegated prompt — **first** **`Task(*-reviewer)`** for this segment (or **`Task(plan-reviewer)`** at gate 1), **then** **`Task(scrum)`** for this segment with the same context appended. After both complete, **offer the manual gate again** unless the user chose **Proceed**.

### Interaction with `--review` (**orthogonal**)

- **`--review`:** Optional **per-step checkpoints** after individual pipeline steps (existing behavior).
- **`--manual`:** **Mandatory** post-segment gates after plan+plan-review+scrum and after each completed domain track.
- Both may be set; **`--manual`** does **not** imply **`--review`**, and **`--review`** does **not** replace **`--manual`** gates.

### Interaction with `--resume`

- Read the active session file **`docs/sessions/<session-id>/current.md`** (resolve **`session-id`** from **`docs/sessions/ACTIVE_SESSION`**) for the last **`GATE:`** line (and any **`MANUAL_GATE_CONTEXT:`** if present).
- If the run **stopped at a manual gate** (user had not answered **Proceed** / **Force review** / **Add context and review**), **`--resume`** **re-offers** that gate with the same three options — do **not** silently skip it.
- Otherwise continue from the **step after** the last recorded **`GATE:`** / **`FAILURE:`** (same as default **`--resume`**). If unclear whether the pause was at a manual gate, prefer **re-offering** the gate for the segment indicated by the last completed **`GATE:`** line.
- **Implementation phases (`GATE: impl | DONE`):** For specs with **`### Phase N:`** headings, the orchestrator **must** persist **`GATE: impl | DONE | phase: k | …`** after **§ 6** completes for phase *k* (see **§ 6** — after **`Task(scrum)`** **PROCEED**, **`Task(do)`** spec application when Proposed updates exist, then **`GATE:`**). On **`--resume`**, interpret the **last** such line as “phases **1…k** have finished **§ 5–§ 6**”; continue with **§ 5** for phase *k+1*, or **§ 7 QA** if *k* is the final phase. If the last **`GATE: impl | DONE`** has **no** **`phase:`** field (single implicit phase), treat implementation as complete through that gate and continue with the next pipeline step (**§ 7** or **Finish** as appropriate). **Granular telemetry:** **`impl | START`**, **`impl | DONE`**, and **`impl-review | GATE | …`** lines (see **§ 5** / **§ 6**) aid **timelines** and operator tooling; they **do not** replace **`GATE: impl | DONE`** for **`--resume`** ordering.
- **Examples (multi-phase, for unambiguous resume):**
  - After phase 1 **§ 6** completes: `GATE: impl | DONE | phase: 1 | spec: docs/specs/2026-04-10-example-spec.md`
  - After phase 2 **§ 6** completes: `GATE: impl | DONE | phase: 2 | spec: docs/specs/2026-04-10-example-spec.md`
  - If the run stops **during** phase 2 **§ 5** before phase 2’s **§ 6**, the last line should still be **`GATE: impl | DONE | phase: 1 | …`** — **`--resume`** continues phase 2 **§ 5** (does **not** redo phase 1 **§ 5–§ 6**).

## Delegation header

Include on every **`Task`** to a persona:

```text
[DELEGATION MODE: orchestrated]
This task is delegated by the run-pipeline skill (main agent). Behavioral overrides:
1. SKIP routine user confirmation — save outputs directly unless APPROVAL_NEEDED.
2. If you need clarification, prefix with QUESTION:.
3. If blocked on approval, prefix with APPROVAL_NEEDED:.
4. Return structured result: spec path, scores, files touched, blockers.
5. OVERRIDE for mutating git / GitLab: persona agents never run `git commit`, push, or MR creates. The orchestrator may run **`scripts/hooks/pipeline-commit.sh`** mid-pipeline when **`commit_policy`** authorizes (**Commit policy**), and **`scripts/hooks/pipeline-finish.sh`** only per **run-pipeline § 9 Finish** (commit flags when the user selects an offered message; **`--push true`** only after explicit Yes to the push prompt); MR create/update is performed by the orchestrator via the **GitLab MCP** (`mcp__GitLab__*`) only after explicit user confirmation, presenting the MR title/body for review first.
6. Spec progress under orchestration: **Do not** flip task checkboxes **`[x]`**, **`status`**, or **`last-updated`** in the spec file. Return **Proposed spec updates** for **`Task(do)`** **only** after the **`Task(scrum)`** that matches your work (**plan gate**, **§ 6** phase gate, or **post-QA § 7.1** — see skill) returns **PROCEED** — the **main session** delegates a batched **`Task(do)`**; it does **not** edit the spec itself (see **Task(do) for authorized spec updates**). Standalone **`/dev`** / **`/sre`** / **`/data`** / **`/qa`** without this header may still update the spec per their agent files where applicable.
7. **No nested delegation:** Do **not** invoke **`Task(...)`** on other personas or reviewers from inside your run. Escalate with **`QUESTION:`** / **`APPROVAL_NEEDED:`**; the **main session** orchestrator is the only component that schedules **`Task`** chains.
8. **Least privilege (artifacts):** Assemble each **`Task`** prompt using the **Least-privilege matrix** below. **Do not** attach paths or payloads that row **Must exclude** forbids for that consumer unless the user explicitly overrides (standalone persona / out-of-band instruction).
9. **Zero Trust Shell (`Task(do)`):** Use **`scripts/tools/query-transcript.py`** for transcript reads — **not** inline **`python3 -c`**, JSONL/bash parsing loops, or ad-hoc **`git mv`** / **`git add`** for those jobs. Do **not** fabricate missing **`artifacts/scanners/`** (or other QA prep) files; missing prep → escalate / fail closed.
```

### Least-privilege matrix (orchestrator prompt assembly)

Normative for **`/run`** prompt construction. **Canonical on-disk trees** under **`docs/sessions/<session-id>/`**: bounded MCP / pre-plan handoffs **`pre-plan/`** (see **Pre-plan context — single writer**); explorer reports **`artifacts/explorer/`**; QA prep scanners **`artifacts/scanners/`**; domain diffs **`artifacts/diffs/<domain>/`**. **No** session-root symlink aliases (**`exploration`**, **`qa-artifacts`**) — use these **`artifacts/...`** paths in prompts and persistence only (see **Non‑negotiables** item **9**). **`qa-report.md` is NOT a session artifact** — it is written by `Task(qa)` directly to the **ticket folder** (`<ticket-folder>/qa-report.md`) and is persistent/tracked alongside `prd.md`, `spectech.md`, `tasks.md`.

| Consumer | May include in prompt | Must exclude (unless standalone / explicit user override) |
|----------|----------------------|-----------------------------------------------------------|
| **`Task(prd)`** | Ticket-folder path/goal, condensed **Pre-plan context**, paths under **`pre-plan/`** (merged brief + specialists), paths under **`artifacts/explorer/`** | Raw **`artifacts/diffs/`**, full dumps of **`artifacts/scanners/`** |
| **`Task(dev|sre|data)`** | Spec (+ phase slice), **`WORKTREE_PATHS`**, **`working_directory`** = **target root** when multi-root **`attach-target.txt`** is active (same path as **§ 1** **`TARGET_ROOT`**) | **`pre-plan/`** MCP-class files, **`<ticket-folder>/qa-report.md`**, prior **`Task(*)`** transcripts; **`artifacts/explorer/`** only if that persona returned **`REQUEST_MAIN: codebase-explorer`** and the orchestrator persisted output |
| **`Task(*-reviewer)`** | Spec, **only** that domain’s material under **`artifacts/diffs/<domain>/`** | Other domains’ diffs, MCP briefs |
| **`Task(scrum)`** (§ 6 — per-phase **implementation gate**) | Spec (+ phase slice), **reviewer** scores / structured findings; **`phase-<N>-security.md`** **path** and **bounded excerpt** or severity summary (per **Minimal context chain**); optional **`session-memory`** gate lines | Raw **`artifacts/diffs/`** blobs, **unbounded** full-file pastes of **`phase-<N>-security.md`** or multi-phase scanner history, **`pre-plan/`** / MCP-class dumps |
| **`Task(qa)`** | Spec, **`artifacts/scanners/`** (validator + security), **high-level** cross-domain diff summary per this skill (not per-file dev chatter), **`review-report`** skill | Raw **`Task(dev|sre|data)`** transcripts, **`pre-plan/`** / **`artifacts/mcp-briefs/`** large merges |
| **`Task(summary)`**, **`Task(scrum)`** (§ 7.1 — **post-QA** / Finish-adjacent) | **`<ticket-folder>/qa-report.md`** (when present — written by `Task(qa)` to the ticket folder), gate scores / **`session-memory`** lines as today | Full diffs, **full** scanner raw files (same “no full scanner dumps” intent as today), explorer maps, MCP briefs |

**§ 6 vs § 7.1 `Task(scrum)`:** The § 6 row **authorizes** a **bounded** injection of the **phase** security artifact (**`phase-<N>-security.md`** path + excerpt)—shift-left gate context. The § 7.1 row stays aligned with **existing** least-privilege: **no** dumping full session-level scanner bundles into the prompt; aggregate **scores** / **QA narrative** / **session-memory** summaries instead.

**Minimal context chain** — In the body of each **`Task`** prompt (after the header), pass only what the delegate needs per the **matrix**: **spec path** (or resolved slug), **phase / domain slice** (e.g. “Phase 2 `[dev]` only”), and **condensed Pre-plan context** when applicable (merged brief bullets — **not** full upstream **`Task`** logs or raw tool dumps). **For `Task(prd)` specifically (including attempt 1):** the orchestrator passes **only** merged-brief-class **`Pre-plan context:`** and the **user goal** — **not** orchestrator chain-of-thought, main-session reasoning narration, or raw pre-plan specialist dumps. Do **not** paste entire prior subagent transcripts into **`Task(prd)`** / **`Task(dev)`** / etc.

Append **`WORKTREE_PATHS: {...}`** when worktrees are in use.

### Scrum authority and spec `status` (orchestrated `/run`)

- **`/scrum`** is the **only gate** that **authorizes** transitions of spec **`status`** (e.g. **draft → in-progress / review → completed**) and **task checkbox** / **`last-updated`** updates that reflect **gate outcomes**, when running under **`[DELEGATION MODE: orchestrated]`**. Reviewers (**`*-reviewer`**), **`Task(qa)`**, and implementation personas **recommend** outcomes and return **Proposed spec updates**; they **do not** treat the spec as finally signed off until **`Task(scrum)`** returns **PROCEED** for that segment (implementation phases use **§ 6** scrum; plan segment uses **§ 4** scrum; **post-QA** uses **§ 7.1** scrum — see below).
- The **main session** **does not** patch **`docs/specs/...`** itself after **`Task(scrum)`** **PROCEED**. It delegates **`Task(do)`** with **Proposed spec updates** from personas. This preserves **flat** orchestration (no persona calls **`Task(scrum)`** itself).

#### Task(do) for authorized spec updates

After **each** **`Task(scrum)`** **PROCEED** that includes **Proposed spec updates** for a gate, delegate **one** batched **`Task(do)`** for **that gate** **before** the next pipeline step that needs those updates (e.g. next **§ 5** phase, **`GATE:`** persistence that assumes updated checkboxes, **`Task(summary)`**). If a gate returns **PROCEED** with **no** Proposed spec file edits, **skip** spec-targeting **`Task(do)`** for that gate.

**`Task(do)` prompt shape (default — non‑negotiable):**

- Apply **only** the active target's files for this run: **`docs/specs/<spec-slug>.md`** (single-file spec, if ever encountered) **or** — the normal case for this orchestrator — **ticket-folder mode**: **`docs/specs/<ticket-folder>/tasks.md`** checkboxes **and**, in the same batch, that folder's **`_state.json`** (`steps`, `current_step`, `updated_at`, and — for the plan-segment gate — `prd-validated`/`spectech_profile`/`ready-for-dev` as applicable) **plus one** **`_notes.md`** entry (implements D4). This is the **same** gate-authorized batch as the `tasks.md` checkbox update — no new privilege, no separate trigger.
- Include the batched **Proposed spec updates** from the prior persona result(s) for that gate (checkboxes, **`status`**, **`last-updated`**, **`## QA Review`** blocks, etc.) **and** the batched **`_state.json`**/**`_notes.md`** updates for that same gate.

**On failure:** Surface the error; **do not** fall back to main-session spec edits—retry **`Task(do)`** or **`AskQuestion`** / escalate per **Error handling**.

### Escalation and user prompts

- **`AskQuestion`** (when available) is used by the **main session orchestrator** for structured **user** choices (Finish prompts, optional **human intervention** after max self-heal iterations, etc.). **Persona agents** do **not** call **`AskQuestion`**; they prefix **`QUESTION:`** / **`ASK_USER`** / **`APPROVAL_NEEDED:`** so the orchestrator can relay or **`AskQuestion`** on the next turn.
- **Session file for escalation context:** Record **`ESCALATION:`** / **`PLAN_REVIEW_FEEDBACK:`** / **`IMPL_SEGMENT_FEEDBACK:`** lines in **`docs/sessions/<session-id>/current.md`** (from **`ACTIVE_SESSION`**) via **`session-memory.sh write`** so **`--resume`** and the next **`Task(prd)`** / **`Task(dev)`** see the same narrative. Optionally add a short **`## Escalations`** block in that file if multiple threads need separation.

## Pipeline steps (order)

Execute in order unless `--resume` picks up from the active session **`current.md`** (`GATE:` / `FAILURE:` lines — path under **`docs/sessions/<session-id>/`**, id from **`ACTIVE_SESSION`**). When **`--manual`**, insert **manual gates** between the plan segment and implementation, and between domain tracks and QA, per **Manual step gates (`--manual`)**.

### 1. Preconditions — branches and worktrees

For each **working repo** that will be modified:

1. **Multi-root detection (attach-target / session.code-workspace):** Read **`docs/sessions/ACTIVE_SESSION`** for **`session-id`**. Treat multi-root attach as **active** when **`docs/sessions/<session-id>/attach-target.txt`** exists **and/or** **`docs/sessions/<session-id>/session.code-workspace`** exists (artifacts from **`attach-project.sh`**). When **`attach-target.txt`** exists, read the **first non-empty line** (trim surrounding ASCII whitespace) as **`TARGET_ROOT`** — an absolute path to the **writable** implementation repo; if that path is not a directory, treat **`TARGET_ROOT`** as **unresolved**. If **`session.code-workspace`** exists but **`attach-target.txt`** is missing or **`TARGET_ROOT`** is **unresolved**, **stop** with **`QUESTION:`** / **`AskQuestion`** so the user confirms the target clone path (**do not** silently parse the workspace JSON in the orchestrator). **Do not** run **§ 2 Init** or **`git-inspect`** against the target until **`TARGET_ROOT`** is resolved when multi-root attach is active.
2. **Read-only branch detection:** If multi-root attach is active and **`TARGET_ROOT`** is still **unresolved**, skip this step until step 1 is satisfied. Otherwise let **`INSPECT_ROOT`** be **`TARGET_ROOT`** when multi-root attach is active **and** **`TARGET_ROOT`** is resolved; when multi-root attach is **not** active, **`INSPECT_ROOT`** is the **orchestrator** workspace root (folder containing **`scripts/tools/`**). From the **orchestrator** workspace root, run **`scripts/tools/git-inspect.sh`** **once** with **`--repo "$INSPECT_ROOT"`** when **`INSPECT_ROOT`** differs from the orchestrator root; run **`scripts/tools/git-inspect.sh`** **without** **`--repo`** when they are the same. In stdout, under **`=== repo ===`**, read **`branch:`** for the current branch name. If **`WORKTREE_PATHS`** points at a **different** clone root than **`INSPECT_ROOT`**, repeat read-only inspection for that path with **`git-inspect.sh --repo <that-root>`** before branch consent.
3. If branch is **protected** (`main`, `master`, `develop`, `release/*`): **stop and ask** the user: stay and abort, use current non‑protected branch, or **create a new branch** — user must **approve the branch name**. Do **not** auto‑create.
4. Optionally **`git worktree add <path> HEAD`** in **the same working repo** as **`INSPECT_ROOT`** for isolation (**narrow `git` exception** per **Non‑negotiables** item **10**). Record paths for **`WORKTREE_PATHS`** (paths inside that repo only when multi-root attach is active).

**Ordering (gate):** Finish **§1** for every relevant working repo **before** **§2 Init**, **Pre-plan context (optional MCP)**, or **`Task(prd)`**. If the user **aborts** at branch consent, **do not** run Init, pre-plan, **`Task(mcp-*)`**, or **`Task(prd)`**. **No** pre-plan **`Task(mcp-*)`** and **no** **`Task(prd)`** until protected-branch / branch-choice questions are **resolved** (or the run ends). Session layout and on-disk pre-plan artifacts are described in **`docs/run-pipeline-reference.md`** — **Session storage**, **Init script stdout**, and **Local auditing**.

### Commit policy (mid-pipeline vs Finish)

**Authority:** Only the **main session** orchestrator commits. Personas (**`dev`**, **`*-reviewer`**, **`scrum`**, etc.) **never** run **`git commit`**. Schema: project skill **`bcs-ticket-workflow`** → **`_state.json.commit_policy`**.

**When to ask:** After **§ 1** branch consent (and ideally after **§ 2 Init** so the ticket folder is known), **before the first § 5** **`Task(dev|sre|data)`**. If **`_state.json.commit_policy`** already has **`mode`** + **`consent`** + **`asked_at`**, **do not** re-ask unless the user requests a change. On **`--resume`**, reuse the stored policy.

**`AskQuestion` (preferred) — two questions** (or numbered chat fallback):

1. **Granularity**
   - **End only** → `mode: end` (commits only at **§ 9 Finish** — legacy default when policy is unset).
   - **Per phase** → `mode: per_phase` (after § 6 **PROCEED** + authorized **`Task(do)`** for that phase, if dirty).
   - **Per task** → `mode: per_task` (after each implementation **`Task(dev|sre|data)`** slice when dirty). Prefer **one** unchecked **`tasks.md`** bullet per implementation **`Task`** when this mode is selected.
2. **Consent**
   - **Authorize all mid-pipeline commits for this run** → `consent: batch`.
   - **Ask me before every mid-pipeline commit** → `consent: each`.

Always set **`rework_prefix`: `fix`** unless the user overrides. Persist via **`Task(do)`** (or main-session ticket update) into **`_state.json.commit_policy`** (include **`asked_at`** ISO UTC). Append one line to **`_notes.md`** and **`session-memory.sh write "COMMIT_POLICY: mode=<…> consent=<…>"`**.

**Executing a mid-pipeline commit:**

1. Confirm the working tree is dirty (**`git-inspect.sh`** — porcelain / status). If clean, skip.
2. Compose a **conventional** message (`feat` / `fix` / `chore` / …). After a § 6 **REWORK** loop, use type **`fix`** (honor **`rework_prefix`**).
3. If **`consent: each`**: **`AskQuestion`** with the proposed message (Commit / Skip). On Skip, leave dirty and continue.
4. If **`consent: batch`** (or user accepted in step 3): run **one** Shell  
   **`scripts/hooks/pipeline-commit.sh --commit-message '<exact>'`**  
   (or **`--commit-file`**). Optional **`--repo`** when not using attach-target.
5. **Never** pass **`--push`** here — push remains **§ 9** only.
6. On hook failure: stop; surface stderr; do **not** invent a raw **`git commit`** workaround.

**Checkpoints:**

| `mode` | When to run steps 1–6 |
|--------|------------------------|
| `end` / unset | Never mid-pipeline |
| `per_task` | After each **`Task(dev|sre|data)`** returns successfully (and after any immediate **`Task(do)`** for that slice’s Proposed updates, when present) |
| `per_phase` | After § 6 **PROCEED** + **`Task(do)`** for that phase (when Proposed updates exist), before **`GATE: impl | DONE`** / next phase |

**§ 9 Finish:** Still runs **`pipeline-finish.sh`** for any **remaining** dirty state + push/MR/audit. If mid-pipeline already committed everything, Finish may be **`--no-commit`** + optional push.

### 2. Init

Runs **after** **§1** is complete. **Do not** start Init until branch consent for protected branches is resolved per **§1** (see **Ordering (gate)** there).

Run **one** Shell invocation from the **workspace root**:

- **Without `--resume`:**  
  `scripts/hooks/pipeline-init.sh`  
  Optionally pass **`--slug <kebab-case>`** when a session suffix is desired. Pass **`--targets`** with one or more workspace-relative directories (from **Parsed inputs** / targets) so **`knowledge/<dir>/_index.md`** can be evaluated — e.g. `scripts/hooks/pipeline-init.sh --targets myapp other-lib`.
- **With `--resume`:**  
  `scripts/hooks/pipeline-init.sh --resume`

**Semantics (inside the script — do not duplicate as separate Shell steps):** **`begin-run`** (when not resuming), **`write-trace-anchors`** (with **`--resume`** when resuming), **`apply-models.sh --snapshot`**, **`session-memory.sh read`**, and optional **`KNOWLEDGE_SOURCES`** **`session-memory.sh write`** when both ARC (see stdout **`arc-declared-in-mcp-json`**) and checked local KB are absent. **Non-zero exit** from **`pipeline-init.sh`** is a hard failure — stop the pipeline. **Parsed stdout:** use **`=== … ===`** section headers documented in **`docs/run-pipeline-reference.md`** — **Init script stdout**.

- **Manual model mode:** If **`=== model-mode ===`** output indicates **`manual`**, treat the pipeline as **manual model mode** — see **Model plan** below. Otherwise use team baseline plus dynamic per-step model selection. **Independent of orchestration:** **`--manual` step gates** (pause after plan segment and each domain track) are **not** manual model mode; for orchestration pauses see **Manual step gates (`--manual`)**.
- **Snapshot path:** Read **`snapshot-path:`** from **`pipeline-init.sh`** stdout (same as **`APPLY_MODELS_SNAPSHOT`** / default under **`docs/sessions/.model-snapshot`**). In **manual model** mode, per-step **`apply-models.sh`** overrides are skipped per **Model plan**; the Init snapshot still records frontmatter.
- **Session memory read:** Use the tail of **`=== session-memory-read ===`** in **`pipeline-init.sh`** stdout to surface prior gates (equivalent to **`session-memory.sh read`**).
- **Multi-root attach:** **`pipeline-init.sh`** always runs as **one** Shell invocation from the **orchestrator** workspace root (same command as above). **`write-trace-anchors`** / **`trace-hash-root:`** already follow **`attach-target.txt`** when present (**`docs/run-pipeline-reference.md`** — **Session trace anchors**). The orchestrator does **not** run Init inside the target clone.

### Pre-plan context (optional MCP)

Runs **after** **Init** and **before** the **PRD/Spectech/Tasks segment (`Task(prd)`)**. **Anchor:** use this **heading title** (and **PRD (`Task(prd)`)**) in addition to section numbers — numbers may shift; titles are stable.

**When to run:** On **`/run`** when **`Task(prd)`** will execute. **Skip the entire segment** when **`--skip plan`** is set (pre-plan is tied to skipping the front-end segment). **Standalone `/prd`** (not via **`/run`**) does **not** use this skill segment; the prd persona may still use optional MCP per its Toolbox.

**Optional MCP:** GitLab, Atlassian (Jira/Confluence), Glean, and **ARC** (AvaTax Release Central) require **`.mcp.json`** where applicable (see **§ 2 Init** / **CLAUDE.md**). If MCP is unavailable or **`Task(pre-plan-triage)`** indicates **no** external sources are needed, **do not** delegate the corresponding **`Task(mcp-*)`**; record a one-line note via **`session-memory.sh write`** (e.g. pre-plan external context skipped — no MCP or triage none).

**ARC MCP — two lanes:** **(A) Pre-plan:** When triage lists **ARC / AvaTax / RC / schema / catalog** needs, the **`/run`** orchestrator delegates **`Task(mcp-arc)`** from the **main session** in **Wave 1** alongside **`Task(mcp-glean)`** when that is also listed — bounded, capped briefs; **not** nested inside **`Task(prd)`**. **(B) In-session:** **`/prd`** (and **`/kb`** where applicable) may invoke **ARC MCP tools** in **their own** sessions when configured (repo-scoped discovery). Under orchestrated **`/run`**, **`/dev`** and **`/fix`** **do not** call ARC MCP directly — they return **`REQUEST_MAIN: ARC <query>`**; the orchestrator runs **`Task(mcp-arc)`**, persists under **`pre-plan/specialists/`**, and re-delegates (see **§ 5** — **Mid-run enterprise context**). Lane **(B)** does **not** replace lane **(A)** when triage said ARC was needed for **`/run`** pre-plan. **`/prd` must not** nest **`Task(mcp-arc)`** or other **`Task(mcp-*)`** internally for **`/run`** MCP gather — that would be **nested**; the orchestrator stays **flat**.

**Steps (orchestrator-flat — main session only, two-wave pre-plan):**

1. **`Task(pre-plan-triage)`** — Pass user goal and `/run` flags. Expect structured triage: **`wave1_sources`** (subset of **`glean`**, **`arc`**) and **`follow_up`** / **`wave2_sources`** ( **`jira`**, **`confluence`**, **`gitlab`** ), **`jira_keys`**, **`confluence_space`**, **`gitlab_refs`**, **`gate_hints`**, query hints, caps — see **`.claude/agents/pre-plan-triage.md`**.

2. **Wave 1 — parallel breadth (Glean + ARC only when listed)** — If triage lists **`glean`** and/or **`arc`** for wave 1, delegate **`Task(mcp-glean)`** and/or **`Task(mcp-arc)`** **in parallel** (`run_in_background` + **`Await`**). **Skip Wave 1** when triage lists **neither** (e.g. goal is **only** a Jira ticket or GitLab MR path — **Wave 2**-only). Use **`Task(..., description="…")`** when supported — see **§ 5** (**Task display names**). **After each specialist `Task` completes**, write a **bounded** snapshot to **`docs/sessions/<id>/pre-plan/specialists/{glean,arc}.md`** for specialists that ran. Resolve **`<id>`** with **`scripts/tools/session-memory.sh session-root`**. Prefer **`session-handoff.sh write-handoff specialist <name>`**.

3. **Merge + gate (after Wave 1, or immediately after triage if Wave 1 skipped)** — In the main session: merge Wave 1 results into a working brief (dedupe, caps). **Gate for Wave 2:** Run **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, and **`Task(mcp-gitlab)`** **only if** triage **or** the merged Wave 1 brief indicates need — e.g. **`jira_keys`** / **`confluence_space`** / **`gitlab_refs`** in triage, **`gate_hints`** true for a source, or the merged brief asks for ticket/wiki/MR follow-up. **Do not** invoke Wave 2 specialists “just in case.” If multiple Wave 2 specialists apply, they may run **in parallel** (`run_in_background` + **`Await`**). **After each Wave 2 `Task` completes**, write **`pre-plan/specialists/{jira,confluence,gitlab}.md`** for specialists that ran.

4. **Final merge** — Produce one **Merged external brief** for **`Task(prd)`** (all waves combined; not raw tool dumps). **Persist** as **`docs/sessions/<id>/pre-plan/merged-brief.md`**. Prefer **`session-handoff.sh write-handoff merged`**.

5. **`Task(prd)`** — Append a **`Pre-plan context:`** block: **summarized** merged brief (bullet-style pointers are OK) plus pointers from triage. Include the user goal as today. **Do not** pass full pipeline history, nested subagent logs, or **raw** specialist tool JSON as the primary payload — condense to a bounded brief (see **`merged-brief.md`** on disk in **`docs/run-pipeline-reference.md`** — **Session storage**).

**Handoff on-disk contract:** **`pre-plan/merged-brief.md`** = merged brief after each merge step relevant to **`Task(prd)`**; **`pre-plan/specialists/<name>.md`** = one file per **`mcp-*`** run (**`name`** ∈ **`glean`**, **`arc`**, **`jira`**, **`confluence`**, **`gitlab`**). Content is **capped** (concise summaries — not raw unlimited MCP dumps). See **`docs/run-pipeline-reference.md`** — **Session storage**, **Pre-plan MCP gather**, **Local auditing** (how to inspect **`pre-plan/`** proofs locally).

**Single writer — MCP brief class (no duplicate unbounded dumps):** The orchestrator **writes** bounded MCP / merged content **only** under **`pre-plan/`** via **`session-handoff.sh`** (and the same paths for mid-run **`REQUEST_MAIN`** snapshots into **`pre-plan/specialists/`**). **`artifacts/mcp-briefs/`** is the **LPP namespace** reserved for least-privilege session layout (empty scaffold by default) — **do not** copy full **`merged-brief.md`** bodies into a second parallel tree. **`Task(prd)`** prompt path references use **`pre-plan/...`** (same artifact class the matrix labels **`artifacts/mcp-briefs/`** for injection rules).

**Nested vs flat:** Only the **main session** orchestrates **`Task(pre-plan-triage)`** and pre-plan **`Task(mcp-*)`** in **waves** (Wave 1: Glean/ARC; Wave 2: Jira/Confluence/GitLab when gated). **`/prd` must not** invoke **`Task(mcp-*)`** internally for this gather when running under **`/run`** — that would be **nested** and is discouraged. **`/prd`** may still call **ARC MCP tools** directly in its **own** session when **not** relying on the orchestrator for that fetch (lane **(B)** — standalone **`/prd`**; under **`/run`**, mid-run **`REQUEST_MAIN`** uses orchestrator **`Task(mcp-*)`**). See **`docs/reference/cursor-agents.md`** (Nested **`Task`** / subagent reliability) and **`docs/run-pipeline-reference.md`** (Pre-plan MCP gather; nested vs flat).

**Reuse:** If implementation review, QA, scrum, or **mid-run** **`REQUEST_MAIN`** / enterprise **`QUESTION:`** (see **§ 5** — **Mid-run enterprise context**; **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`** — **Mid-run `REQUEST_MAIN` scope**) needs more Jira/Confluence/Glean/GitLab/ARC context, the orchestrator may run triage (or skip if already clear) and **only** the needed **`Task(mcp-*)`** calls following the **same wave rules** (Glean/ARC in parallel when both needed in wave 1; Jira/Confluence/GitLab after merge + gate when needed), merge, persist to **`pre-plan/specialists/`** when applicable, then attach to the **next** persona prompt — still **from the main session**, not nested inside **`/prd`** or **`/dev`**.

### 3–4. PRD/Spectech/Tasks segment — `Task(prd)`→`Task(spectech)`→`Task(tasks)`, then **`Task(plan-reviewer)`** (folder mode) self-heal, then **`Task(scrum)`**

Implements spectech's **D2**. Skip the whole segment only if **`--skip plan`** (pre-plan is skipped with it; flag name unchanged — only its content changes: three artifacts + folder-mode review instead of one artifact). There is **no** `Task(plan)` in this orchestrator (FR-4) — the front end is always this three-persona sequence.

#### 3. PRD → Spectech → Tasks (`Task(prd)` → `Task(spectech)` → `Task(tasks)`)

- **First attempt:** Determine which of `prd`/`spectech`/`tasks` is not yet `done` in the ticket folder's `_state.json.steps` (see **Ticket-folder validation**), then run `Task(prd)`, `Task(spectech)`, `Task(tasks)` **in that fixed order**, one at a time — each is a **separate** `Task` delegation to its own persona; no persona calls another (flat orchestration). Pass the **folder path**, **`Pre-plan context:`** as already merged (see **Pre-plan context**), and the **user goal** (or Jira-key context per **Ticket-folder resolution**). Follow **Minimal context chain** — **no** orchestrator chain-of-thought in the prompt body.
- Each of `Task(prd)`, `Task(spectech)`, `Task(tasks)` **self-validates internally** before returning `done` in `_state.json.steps` (`prd-validator`, spectech's Self-Review checklist, tasks' Coverage self-review — see each agent's own Workflow) — the orchestrator does not re-validate their content itself; it schedules the next of the three once the prior one reports `done`.
- **Exploration escalation (`REQUEST_MAIN: codebase-explorer`):** none of `Task(prd)`, `Task(spectech)`, `Task(tasks)` requests `codebase-explorer` (unlike the retired `Task(plan)`) — `spectech`'s own `spectech-analyzer` skill does codebase analysis inline. If a future revision of one of these personas adds this escalation, handle it identically to **§ 5**'s **Mid-run enterprise context** pattern (persist under `artifacts/explorer/`, re-invoke the same persona with the pointer).
- **Later attempts (self-heal):** If **§ 4** did not accept the draft set (see below), re-run **only** the specific persona(s) that **`Task(plan-reviewer)`**'s cross-artifact findings point at — **never** a blind re-run of all three (D2). **Context slicing is non-negotiable** (aligns with roadmap "strip failed attempt chat history"):
  - **`Plan segment feedback:`** — **Isolated** delta only. Build it from **`PLAN_REVIEW_FEEDBACK:`** (persisted in **`docs/sessions/<id>/current.md`**) **and** structured **`Task(plan-reviewer)`** findings (gaps, requested edits, weakest factors, **and which artifact(s)** — `prd`/`spectech`/`tasks` — each finding targets). This block is the **primary** payload for amendment turns; it **replaces** replaying failed-attempt history.
  - **Do not** re-attach the **full** prior `Task(prd|spectech|tasks)` assistant transcript, prior-turn chat history, or redundant replay of **raw** pre-plan specialist logs / tool JSON. If **`Pre-plan context:`** must appear again, use the same **summarized** merged-brief style as attempt 1 (see **`pre-plan/merged-brief.md`**), **not** unbounded dumps.
  - **Optional one line of metadata** — e.g. attempt number, active folder path, and **prior plan-reviewer score(s)** **only** when needed to disambiguate the loop. Scores are **at most** this one-liner; they **do not** substitute for a proper **`Plan segment feedback:`** slice.
  - Incorporate any relevant **`ESCALATION:`** lines from session memory **into** the sliced narrative where applicable — **do not** paste unrelated session history.
  The orchestrator **must** put **`Plan segment feedback:`** (and optional one-liner) in the prompt body — **do not** rely on the persona having read session files unless you also paste the relevant lines.

Persist when each of prd/spectech/tasks completes: **`scripts/tools/log-gate.sh plan-attempt <n> <folder-path>`** (same telemetry call as before, now covering the three sub-steps).

#### 4. Plan-segment review — inner loop (max **`--max-plan-iterations`**, default **3** — parse from `/run` or use **3**)

Skip **`Task(plan-reviewer)`** only if a future **`--skip plan-review`** flag exists (not used by default).

1. **`Task(plan-reviewer)`** **in folder mode** — its existing, already-implemented path (D2) — on the current `prd.md` + `spectech.md` + `tasks.md` set. Its Cross-artifact coverage factor is the primary lens in folder mode. Record score, verdict (**PASS** / **REWORK** or equivalent), weakest factors, and — for **REWORK** — **which artifact(s)** the findings target.
2. **Acceptance for exiting the inner loop:** Plan-reviewer **verdict PASS** **or** overall score **≥** `spectech.md`'s `confidence.threshold` (frontmatter, if present) **or** **≥** orchestrator **`--confidence`** (default **75**) when not declared.
3. **If not accepted** and **attempts < max:** Persist  
   **`scripts/tools/session-memory.sh write "PLAN_REVIEW_FEEDBACK: attempt n | <why + concrete changes + target artifact>"`**  
   and return to **§ 3** — re-run **only** the targeted persona(s) with that feedback in the prompt (never a blind re-run of all three).
4. **If not accepted** and **attempts == max:** Do **not** proceed to implementation. **`AskQuestion`** (or chat fallback) for **human intervention**: e.g. **Proceed anyway** (documented override), **Abort pipeline**, **Provide guidance** (free text → append to session memory → re-run the targeted persona(s) if user wants). Record **`ESCALATION: plan-segment | max iterations`**.

**After** the inner loop succeeds (step 2) **or** after a documented human override:

5. **`Task(scrum)`** (plan segment): Ingest **`Task(plan-reviewer)`** final report, iteration count / trend, and business context. Emit **PROCEED** / **ASK_USER** / **REWORK** per **`confidence-scoring`**. **PROCEED** authorizes moving to **§ 5** and authorizes **`Task(do)`** for **plan-approved** updates — now covering **both** `tasks.md` checkboxes **and** `_state.json.steps.{prd,spectech,tasks}` / `current_step` / `_notes.md` (see **Task(do) for authorized spec updates** — implements D4).

Persist: **`scripts/tools/log-gate.sh plan-review-gate <score> <decision> <attempts>`** and **`scripts/tools/log-gate.sh plan-done <folder-path>`** when the plan segment is fully accepted.

### 5. Implementation

#### Mandatory sequence (per phase)

For each spec **phase** *k* (or the single implicit phase if there are no **`### Phase N:`** headings):

1. **§ 5** — Run implementation **`Task(dev|sre|data)`** for phase *k* only (parallel within the phase when the spec allows and **`--manual`** is off; sequential per track when **`--manual`** — see **Manual step gates**).
   - **Session telemetry (implementation segment):** For **each** **`Task(dev|sre|data)`** you **schedule** for this phase, append **one** line via **`scripts/tools/log-gate.sh impl-start`** **immediately** after scheduling (before **`Await`** returns):
     - **Multi-phase** specs (**`### Phase N:`** present):  
       **`scripts/tools/log-gate.sh impl-start --phase k --domain <dev|sre|data>`**
     - **Single implicit phase** (no phase headings):  
       **`scripts/tools/log-gate.sh impl-start --domain <dev|sre|data>`** (omit **`--phase`**).
   - **After** all **`Task(dev|sre|data)`** for this phase’s **§ 5** batch **complete** (parallel **`Await`** join, or last track in **`--manual`** order), append **one** telemetry line ( **`impl | …`**, not the **`GATE:`** checkpoint — that comes after **§ 6**) via **`scripts/tools/log-gate.sh write-raw`**:
     - **Multi-phase:**  
       **`scripts/tools/log-gate.sh write-raw "impl | DONE | phase: k | spec: <path>"`**  
       Optional suffix **`| domains: dev,sre,data`** inside the quoted line when logging helps.
     - **Single implicit phase:**  
       **`scripts/tools/log-gate.sh write-raw "impl | DONE | spec: <path>"`** (optional **`| domains: …`**).
   - **`--manual`:** Emit **`impl-start`** / **`write-raw` `impl | DONE`** **per domain track** (each **`Task(dev|sre|data)`** → **START**; **`impl | DONE`** after that track’s implementation **`Task`** returns, before **§ 6** for that segment; include **`phase: k`** in the **`impl | DONE`** line when the spec has phase headings).
2. **§ 6** — After the § 5 batch, run **in parallel** domain **`*-reviewer`** (as needed) **and** **`Task(security-scanner)`** scoped to **`phase-impl-delta`**; persist **`phase-<N>-security.md`** (see **§ 6 Implementation review**); **then** **`Task(scrum)`** for phase *k* (batched or per-track per **`--manual`**).
3. **Optional rework loop** — If **`Task(scrum)`** returns **REWORK** / **ASK_USER**, persist **`IMPL_SEGMENT_FEEDBACK:`** (phase, domain, reviewer + scrum rationale) to session memory, then re-run the needed **§ 5** / **§ 6** steps for that phase subject to **`--max-iterations`** (default **3**) for that gate family; do **not** start phase *k+1* until scrum **PROCEED** (or explicit user override) for phase *k*. At the cap → **`ESCALATE`** / **`AskQuestion`** per **Error handling**. Mid-pipeline commits during / after a REWORK loop use conventional type **`fix`** (honor **`commit_policy.rework_prefix`**, default **`fix`**) — see **Commit policy**.
4. **Only then** — Proceed to **§ 5** for phase *k+1* (if any), or to **§ 7 QA** when all phases have passed **§ 6**.

#### Mid-run enterprise context (`REQUEST_MAIN:` / enterprise `QUESTION:`)

**`REQUEST_MAIN: codebase-explorer <target-dir>`** — When raised from **`Task(fix)`** (or other personas when documented — **not** `Task(prd)`/`Task(spectech)`/`Task(tasks)`, which do not use this escalation per **§ 3**), use **§ 3** **Exploration escalation** / **`artifacts/explorer/`** persist-and-re-feed (**`Task(codebase-explorer)`** → bounded report under **`docs/sessions/<session-id>/artifacts/explorer/`** → re-invoke the **same** persona with pointer/excerpt). **Do not** treat **`codebase-explorer`** as an MCP specialist — **do not** run **`Task(mcp-*)`** or persist under **`pre-plan/specialists/`** for this label. For **`Task(fix)`** specifically: re-invoke **`Task(fix)`** after the scout file is written.

When **`Task(dev|sre|data)`**, **`Task(qa)`**, or **`Task(fix)`** returns **`REQUEST_MAIN: <Specialist> <query>`** for **enterprise** specialists (labels: **Glean**, **Jira**, **Confluence**, **GitLab**, **ARC** — consistent with **Pre-plan context** and **`.claude/agents/pre-plan-triage.md`**) or an enterprise-scoped **`QUESTION:`** that requires external evidence, the **main session** orchestrator:

1. **Maps** the label to **`Task(mcp-glean)`**, **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`**, or **`Task(mcp-arc)`** — **only** from the main session. **Do not** nest **`Task(mcp-*)`** inside **`Task(dev|sre|data|qa|fix|plan)`** for enterprise fetch.
2. **Persists** a **bounded** markdown snapshot under **`docs/sessions/<session-id>/pre-plan/specialists/`** using a **unique** filename so mid-run outputs do **not** overwrite pre-plan wave files (e.g. **`jira-request-<timestamp>.md`**, **`mid-run/jira-001.md`** — see **`docs/run-pipeline-reference.md`** — **Session storage**).
3. **Appends** traceability via **`session-memory.sh write`** (e.g. **`MID_RUN_MCP:`** or equivalent — specialist, path, one-line reason).
4. **Re-delegates** the **same** spec **phase** and **domain** **`Task(dev|sre|data)`** with the saved file **path** or **excerpt** in the prompt (**Minimal context chain** — no raw unlimited dumps).
5. **Same pattern for QA and fix:** After persist and **`session-memory`**, **re-invoke** the same **`Task(qa)`** or **`Task(fix)`** with a **pointer** or **excerpt** to the saved specialist file when mid-run MCP was triggered from those personas — **parallel** to step **4** for **`Task(dev|sre|data)`**.

**PRD/Spectech/Tasks segment (§ 3–4):** The **same** persist-and-re-feed pattern applies when **`Task(prd)`** (or `Task(spectech)`/`Task(tasks)`) returns **enterprise** **`REQUEST_MAIN`** (MCP specialists above) or an enterprise **`QUESTION:`** — re-invoke the **same** persona with the pointer to **`pre-plan/specialists/`**. **`REQUEST_MAIN: codebase-explorer`** uses **`artifacts/explorer/`** per **§ 3** — **not** **`pre-plan/specialists/`**. Authoritative scope for MCP mid-run: **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`** — **Flow**, **Mid-run `REQUEST_MAIN` scope (plan segment vs §5)**.

**`Task(qa)` / `Task(fix)`:** If mid-run QA or **`Task(fix)`** (e.g. after **Error handling** escalation) needs external evidence, the orchestrator runs the matching **`Task(mcp-*)`** using steps **1–3** above, then **step 5** (re-invoke **`Task(qa)`** or **`Task(fix)`**) — personas **do not** invoke enterprise MCP inside their session under orchestrated **`/run`**.

**ARC:** Under orchestrated **`/run`**, **`/dev`** and **`/fix`** **do not** call **ARC MCP** tools directly; they return **`REQUEST_MAIN: ARC <query>`** and the orchestrator runs **`Task(mcp-arc)`** then persists and re-delegates. **Reuse** (under **Pre-plan context**): mid-run discovery **reuses** the **same wave rules** as pre-plan and implementation-review follow-up MCP (**Glean/ARC** parallel in wave 1 when both apply; **Jira/Confluence/GitLab** after merge + gate when needed).

**Spec phases (`### Phase 1:` … `### Phase N:`):** If the active spec uses phase headings, the orchestrator **must not** delegate a single **`Task(dev)`**, **`Task(sre)`**, or **`Task(data)`** that spans **more than one** spec phase. **At most one spec phase** per implementation **`Task(domain)`** — the prompt covers **only** that phase’s tasks for that domain (and repo tag if used). **Same persona across phases** (e.g. every phase is only `[dev]`): still run **separate** **`Task(dev)`** (or `sre`/`data`) **per phase**; do not merge phases for efficiency.

**Task display names** — So parallel **`Task`** runs are distinguishable in UI/logs, use **`Task(..., description="…")`** when the Claude Code **`Task`** API supports it:

- **Implementation:** **`Dev (Phase &lt;N&gt; — &lt;spec-slug&gt;)`**, **`Sre (Phase &lt;N&gt; — &lt;spec-slug&gt;)`**, **`Data (Phase &lt;N&gt; — &lt;spec-slug&gt;)`** (adjust **Phase** / domain to match the active spec slice). Example: **`Dev (Phase 2 — mcp-arc-preplan-orchestration-spec)`**.
- **Pre-plan MCP specialists:** e.g. **`MCP-ARC (pre-plan — &lt;spec-slug&gt;)`**, **`MCP-Glean (pre-plan — &lt;spec-slug&gt;)`** — same **spec slug** as the active run when known.

**Fallback** — If **`description`** is unsupported or ignored, put the **same label as the first line** of the **`Task`** prompt body (or an agreed session-memory **`DISPLAY_NAME`** line) so operators can still tell delegations apart.

**Order across phases:** Finish **implementation for phase *k*** (see parallelism below), then run **§ 6 Implementation review** for phase *k* (**parallel** domain **`*-reviewer`** and **`Task(security-scanner)`** with **`phase-<N>-security.md`**, **then** **`Task(scrum)`** — see **§ 6 Implementation review**; per default or **`--manual`** rules), **before** starting **implementation for phase *k+1***. If the spec has **no** `### Phase N:` headings, treat the whole task list as **one** phase.

**Parallelism within a single phase:** **Unless `--manual`:** when a phase lists multiple domains, run **`Task(dev)`**, **`Task(sre)`**, **`Task(data)`** **in parallel** with **`run_in_background: true`**, then **`Await`** for all — each with **`description="…"`** per **Task display names** when supported. **With `--manual`:** run each required domain track **one at a time** in spec order **for that phase** (see **Manual step gates (`--manual`)**); persist per track before the manual gate.

#### Implementation payload construction

For **each** **`Task(dev)`**, **`Task(sre)`**, and **`Task(data)`**, build the prompt body as a **least-privilege slice** (only the phase and domain the delegate needs):

1. **Include** — **Only** the active **`### Phase N:`** heading (when the spec uses phases) **and** the **unchecked task lines** tagged for **that** persona’s domain (**`[dev]`** / **`[sre]`** / **`[data]`**, including **`[dev:repo]`**-style tags when used). If there are **no** phase headings, the slice is the whole spec task list **for that domain only** (still **not** other domains’ bullets). When **`commit_policy.mode`** is **`per_task`**, prefer **one** unchecked bullet (or the smallest cohesive group the user already accepted) per implementation **`Task`** so mid-pipeline commits stay granular.
2. **Also include** — Shared orchestration blocks **as defined in this skill:** the **[DELEGATION MODE: orchestrated]** header (and its numbered items), **`WORKTREE_PATHS`** when worktrees apply, **`working_directory`** on the **`Task`** set to the **§ 1** **`TARGET_ROOT`** when multi-root **`attach-target.txt`** is active, and a **condensed** **`Pre-plan context:`** line **only** when still relevant to the slice (same **Minimal context chain** rules — no raw specialist dumps).
3. **Exclude** — **Do not** paste **other** **`### Phase M:`** task sections, **other domains’** task bullets in the same phase, or redundant full-spec copies into a single implementation **`Task`** body. **Overview / Scope / acceptance** may be summarized in one or two lines when the delegate needs orientation; the **task bullets** for the delegation must remain **domain-scoped** as above.

This applies **per** parallel **`Task`** in a phase: **`Task(dev)`** gets **only** **`[dev]`** lines for that phase; **`Task(sre)`** gets **only** **`[sre]`** lines; **`Task(data)`** gets **only** **`[data]`** lines — not a merged “all domains” task list.

**After each implementation `Task` returns:** If **`commit_policy.mode`** is **`per_task`**, run the mid-pipeline commit checkpoint (**Commit policy** — **Executing a mid-pipeline commit**) before starting the next implementation **`Task`** or § 6 for that phase. When domains ran **in parallel**, run checkpoints **sequentially** after **`Await`** (one commit per dirty domain slice, or one combined message if the user prefers — default: **one commit per domain Task** that left the tree dirty).

Examples:

- **Default, one phase, two domains:** Parallel: `Task(dev)`, `Task(sre)` with same spec and `WORKTREE_PATHS`.
- **Default, two phases, dev-only:** `Task(dev)` for phase 1 only → **§ 6** for phase 1 → `Task(dev)` for phase 2 only → **§ 6** for phase 2 — **not** one **`Task(dev)`** covering both phases.
- **Persist `GATE: impl | DONE` (with `phase:` when multi-phase)** only **after** each phase’s **§ 6** completes — see **§ 6** (not immediately after **§ 5** alone).

### 6. Implementation review

**Phase boundary:** For specs with **`### Phase N:`** headings, run **§ 6** for phase *k* **immediately after** phase *k*’s **§ 5** implementation **`Task`** delegations complete — **before** any **§ 5** **`Task`** for phase *k+1*. (If a phase omits a domain, skip that domain’s **`Task`**; still run **§ 6** for the domains that ran in that phase.)

**`phase-impl-delta` (scope for § 6 security scan):** The **change surface** from **that phase’s** § 5 **`Task(dev|sre|data)`** work in the **working repo or worktree** (paths and content those delegations touched)—**not** the whole repository. The orchestrator schedules **`Task(security-scanner)`** with prompt scope aligned to **`phase-impl-delta`** (normative definition in the active spec **Overview** when the term is used).

**Parallel § 6 wave** (unless **`--skip impl-review`**): After phase *k*’s § 5 batch completes, run **in parallel** (`run_in_background` + **`Await`**):

1. Each domain **`*-reviewer`** **`Task`** required for that phase (same domain rules as today), **and**
2. **One** **`Task(security-scanner)`** for phase *k*, scoped to **`phase-impl-delta`**.

**Then** run **one** **`Task(scrum)`** for phase *k* with **combined** reviewer and phase-security context (see **`Task(scrum)` injection** below). Use **`Task(..., description="…")`** when supported — e.g. **`Security-scanner (§ 6 phase k — <spec-slug>)`**.

**`--manual`:** Implementation tracks stay **sequential** per **Manual step gates (`--manual`)**; the orchestrator still runs **one** phase-level **`Task(security-scanner)`** per spec phase (scoped **`phase-impl-delta`**), **in the same § 6 wave as** the **`*-reviewer`** for the **final** implementation track that closes review for that phase, so the phase security summary exists before the **`Task(scrum)`** that ends implementation review for that phase. Do **not** nest **`Task(security-scanner)`** inside **`Task(*-reviewer)`** or **`Task(scrum)`** — **flat** orchestration (main session only).

**Persistence (§ 6 — phase security report):** After **`Task(security-scanner)`** returns, persist its **bounded** Markdown under **`docs/sessions/<session-id>/artifacts/scanners/`** as:

- **`phase-<N>-security.md`** — *N* matches the numeric index in **`### Phase N:`** headings, **or**
- **`phase-1-security.md`** when the spec has **no** **`### Phase N:`** headings (single implicit phase).

**Filename namespace (§ 6 vs § 7.0):** **`phase-*-security.md`** (phase gate, § 6) **do not** collide with § 7.0 QA prep filenames: **`spec-validator.md`** and **`security-scanner.md`** are the **session-level** pair before **`Task(qa)`** — different names, lifecycle, and consumers (**§ 6 `Task(scrum)`** vs **`Task(qa)`**). Successive phases write **`phase-1-security.md`**, **`phase-2-security.md`**, … — distinct files, so earlier phase reports are not overwritten. **`ensure_artifacts_dirs`** in **`scripts/tools/session-memory.sh`** remains the directory owner; for the canonical workspace-relative path to the § 6 file for phase *k*, run **`scripts/tools/session-memory.sh phase-security-path k`** (after **`begin-run`** / active session). **No** wrapper script under **`scripts/tools/`** is required for **`phase-impl-delta`** — schedule **`Task(security-scanner)`** from the main session per this skill; persist Markdown to the path from **`phase-security-path`**.

**`Task(scrum)` injection (§ 6):** Build the prompt per the **Least-privilege matrix** row **`Task(scrum)`** (§ 6). Include **reviewer** scores / structured findings **and** the **`phase-<N>-security.md`** **path** (under the session root) plus a **bounded excerpt** or severity summary — **not** raw **`artifacts/diffs/`** blobs or **unbounded** full-file scanner pastes (full file remains on disk for audit).

**`Task(scrum)`** — Evaluates reviewer scores **and** the phase security summary **plus** business judgment and emits **PROCEED** / **ASK_USER** / **REWORK** (per **confidence-scoring** / scrum agent). **Implementation is not “done” for that phase** until **`Task(scrum)`** returns **PROCEED** (or an explicit user override documented in session output). **Personas do not** mark spec tasks complete or update **`status`** / **`last-updated`** under orchestrated delegation — they return **Proposed spec updates**; after scrum **PROCEED**, delegate **`Task(do)`** to apply spec file progress (see **Task(do) for authorized spec updates**).

Skip **§ 6** only when **`--skip impl-review`** is set (and document the skip); otherwise **§ 6** is required **per phase** before the next phase’s **§ 5**. When **`--skip impl-review`**, **no** **`phase-<N>-security.md`** is required or produced — see **Invalid completion**.

During **§ 6**, after domain **`*-reviewer`** results, **`Task(security-scanner)`** persistence to **`phase-<N>-security.md`** (when required), and **`Task(scrum)`** for this segment are known (batched or per-track per **`--manual`**), persist **one** canonical line via **`scripts/tools/log-gate.sh impl-review-gate`**:

- **Multi-phase:**  
  **`scripts/tools/log-gate.sh impl-review-gate <score> <decision> --phase k --spec <path>`**  
  Optional: **`--attempts n`**; repeat per track with **`| domain: dev`** in session narrative if you log each reviewer separately.
- **Single implicit phase:**  
  **`scripts/tools/log-gate.sh impl-review-gate <score> <decision> --spec <path>`**  
  (omit **`--phase`**.)

**After § 6 completes for phase *k*:** When **`Task(scrum)`** returns **PROCEED**, delegate **`Task(do)`** for batched **Proposed completions** / spec updates for that phase when present (**before** persisting **`GATE: impl | DONE`**). If **`commit_policy.mode`** is **`per_phase`**, run the mid-pipeline commit checkpoint (**Commit policy**) after that **`Task(do)`** (when the tree is dirty). Then persist the **implementation segment checkpoint** for **`--resume`** — **one line per phase completion**, after **§ 6** and any spec **`Task(do)`**, not after **§ 5** alone:

- **Multi-phase** specs (**`### Phase N:`** present):  
  **`scripts/tools/log-gate.sh impl-done --spec <path> --phase k`** (optional **`--domains`**)  
  Use the **numeric** phase index *k* from the spec heading (**`Phase 1`** → **`phase: 1`**).
- **Single implicit phase** (no **`### Phase N:`** headings):  
  **`scripts/tools/log-gate.sh impl-done --spec <path>`**  
  Omit **`--phase`** — the run has only one implementation gate pair (**§ 5 → § 6**).

Optional: add **`| domains: dev,sre`** (or similar) when logging helps operators; **`phase:`** is the field **`--resume`** relies on for multi-phase ordering.

### Context airgap (§ 5–§ 6 → § 7)

When moving from **implementation** (**§ 5–§ 6**) to **QA** (**§ 7**), the orchestrator **does not** forward prior **`Task(dev|sre|data)`** message bodies, full transcripts, or **`pre-plan/`** merges into **`Task(qa)`**. Pass **only** what the **Least-privilege matrix** allows for **`Task(qa)`**: spec (path / slice), **§ 7.0** outputs under **`artifacts/scanners/`**, an agreed **high-level** cross-domain diff summary (inline or future **`artifacts/diffs/`** summary file — keep bounded), and **`review-report`** / persona instructions — **not** MCP briefs or implementer chat logs.

### 7. QA (`Task(qa)`)

Skip only if `--skip qa`. **`--skip qa`** skips **§ 7.0** (QA prep wave) as well as **`Task(qa)`** and downstream **§ 7.1** handling as already documented for skipped QA.

#### 7.0 QA prep wave (before `Task(qa)`)

When **`Task(qa)`** is **not** skipped, **immediately before** each **`Task(qa)`** invocation (default: **re-run** this wave before **each** **`Task(qa)`** attempt after QA rework so reports stay aligned with the latest spec/diff — document **reuse** only if you intentionally skip a re-run):

1. Run **`Task(spec-validator)`** and **`Task(security-scanner)`** **in parallel** (`run_in_background` + **`Await`**).
2. **Persist** each **bounded** report under **`docs/sessions/<session-id>/artifacts/scanners/`** using these **canonical filenames** (parity with agent ids; legacy docs may refer to **`qa-artifacts/`** as a name — **not** a session path):
   - **`spec-validator.md`** — output from **`Task(spec-validator)`** (suffixed variants only when multiple runs in one session require disambiguation, e.g. **`spec-validator-2.md`**).
   - **`security-scanner.md`** — output from **`Task(security-scanner)`** (same suffix rule if re-run).
   **Canonical path only** — write under **`artifacts/scanners/`**; **`session-memory.sh`** does **not** create **`qa-artifacts`** at the session root (see **Non‑negotiables** item **9**). **Coexistence:** **`phase-*-security.md`** files from **§ 6** (phase gate) may **also** exist in the same directory — **different** names and purpose than this § 7.0 pair (see **§ 6** — **Filename namespace**).
3. **Append** to the **`Task(qa)`** prompt a fixed injection block such as: *“Here are the pre-run artifacts from the spec validator and security scanner:”* followed by **paths** (under the session root) and **one-paragraph summaries** or **capped excerpts** per **Minimal context chain** and the **Least-privilege matrix** — full files remain on disk for human audit; the QA prompt stays bounded.
4. Use **`Task(..., description="…")`** when supported — same pattern as **§ 5** **Task display names**, e.g. **`Spec-validator (QA prep — <spec-slug>)`**, **`Security-scanner (QA prep — <spec-slug>)`**. If **`description`** is unsupported, put the **same label as the first line** of the **`Task`** prompt body.

**Orchestrated behavior (`Task(qa)` body):** **`Task(qa)`** returns a structured report and **Proposed spec updates** (e.g. recommended **`status`** including moves toward **`completed`**, unchecked tasks for rework, suggested **`## QA Review`** content, **`last-updated`**). The **main session** **must not** apply those proposals to the spec file directly (**no** **`apply_patch`** / bulk **`*.md`** edits) — including **`status: completed`**, other **frontmatter** edits, **task checkbox** **`[x]`** flips, or **QA Review** appendices **sourced from QA output** — until **§ 7.1** **`Task(scrum)`** returns **PROCEED** (unless a documented user override); then delegate **`Task(do)`** per **Task(do) for authorized spec updates**. **`Task(qa)`** does **not** “finalize” the spec under orchestration; **§ 7.1** authorization is required. This aligns **`qa`** with **Scrum authority and spec `status`**.

### 7.1 Final `Task(scrum)` (post-QA)

**When:** Immediately after **`Task(qa)`** completes. If **`--skip qa`** was used, **§ 7.1** is **skipped** — record **`FINAL_SCRUM_SKIPPED: --skip qa`** and treat completion as **degraded** unless you run an optional **`Task(scrum)`** on **§ 6** summaries only (document which).

**Purpose:** Aggregate **final** signals: last **`Task(qa)`** report (cross-domain), **`Task(summary)`**-relevant handoff hints, and **session-memory** summaries of **§ 6** gates (per-phase scrum decisions / scores). Emit **PROCEED** / **ASK_USER** / **REWORK** for **pipeline completion** vs **return to implementation or plan**.

- **PROCEED** authorizes **`Task(do)`** application of **final** spec **`status`** (e.g. **completed**) together with any **Proposed spec updates** from **`Task(qa)`** / implementation personas **not yet applied** — **only after** this **PROCEED** may the main session delegate **`Task(do)`** to patch the spec for QA-sourced **`status`**, checkboxes, and related frontmatter (see **Task(do) for authorized spec updates**).
- **PROCEED** (continued): the orchestrator authorizes **`Task(summary)`** and **§ 9 Finish** prompts per normal order below.
- **REWORK** / **ASK_USER** → follow **Error handling**; do **not** emit **`PIPELINE: COMPLETE`**.

Persist (required): **`scripts/tools/log-gate.sh final-scrum <decision>`** (writes **`GATE: final-scrum | <decision>`**) — do **not** skip when **`Task(qa)`** ran and **§ 7.1** executes.

### 8. Summary (`Task(summary)`)

Skip only if `--skip summary`.

**Orchestrated `/run` — prompt boundary:** Build **`Task(summary)`** with a **minimal delegation bundle** only: **QA report excerpt** or structured findings summary, **§ 7.1** **`Task(scrum)`** outcome (**PROCEED** / **ASK_USER** / **REWORK**), **spec path**, and **spec `status`** (and phase context if needed). **Do not** paste **full phase chat logs**, entire prior **`Task`** transcripts, or **whole multi-file raw `git diff`** blobs into the **`Task(summary)`** prompt — those bloat context and duplicate work. **Orchestrator responsibility:** keep the summary prompt **sliced**; **`Task(summary)`** may run **`scripts/tools/git-diff-summary.sh`** (or other **local** scoped reads/scripts **inside** the summary session) to produce an accurate handoff narrative when a condensed diff view is needed — the boundary is **sliced orchestrator input** vs **summary persona’s own local tooling**, not **unbounded** diff or session-history dumps from the main session.

### 9. Finish

After **`Task(summary)`** (or when summary is skipped by flag) and **before** emitting **Completion output**, run the **post-pipeline shipping prompts** below. **All** Finish **`git add` / `git commit` / `git push`** and the **session trace audit** go through **`scripts/hooks/pipeline-finish.sh`** — when the user selects an offered commit message, that choice is **explicit consent** to pass **`--commit-message`** / **`--commit-file`**. **`--push true`** may appear **only** when the user **explicitly answers Yes** to the **Push** prompt. Mid-pipeline commits (if any) already used **`pipeline-commit.sh`** under **Commit policy**; Finish covers **remaining** dirty files + push/MR/audit — if the tree is already clean, prefer **`--no-commit`** unless the user wants an empty/no-op skip. **GitLab/MR** steps require **explicit user confirmation** at that step; once confirmed, the orchestrator creates/updates the MR **via the GitLab MCP** (`mcp__GitLab__*`), always presenting the MR title/body for review first — never silently. **Delegation header** items **5–6** do **not** waive explicit **Push** or **MR** confirmation — see **`CLAUDE.md`**.

**Multi-root attach / `pipeline-finish.sh`:** Optional **target-repo** **git** steps when multi-root **`attach-target.txt`** is active are implemented **inside** **`scripts/hooks/pipeline-finish.sh`** (orchestrator still runs **one** invocation from the **framework** workspace root with the same flags; the script chooses the working tree per multi-root attach design). The **session trace audit** (**`audit-session-trace.py`**) stays as documented in that script (orchestrator-relative paths). **Multi-root detach** (**`session.code-workspace`** removal) is **not** inside **`pipeline-finish.sh`** — it runs **after** the script exits; see **Multi-root detach** below.

#### Post-pipeline shipping prompts (mandatory)

Work from the **active spec path** (from plan/summary context) and summary output when available.

**Tool-first Finish (non-negotiable):** If the **`AskQuestion`** tool is **available** in this session, the orchestrator **must** **call `AskQuestion` first** for Finish **shipping** (commit / push / MR). **Do not** use pasted Finish choices — e.g. **A–E**, numbered commit / push / MR options, or equivalent prose walls — as the **primary** interaction when the tool can be used. **Await** those results **before** **`scripts/hooks/pipeline-finish.sh`**. **After** **`pipeline-finish.sh`** completes (**git** + audit inside the script), if **Multi-root detach** applies, use **`AskQuestion`** again for that **single** binary question (**second** Finish wave — do **not** block **`pipeline-finish.sh`** on detach). When **`AskQuestion`** is **not** available or **fails**, use the **Chat fallback** below — see **Limitation (Claude Code product)**.

##### Structured prompts (preferred): `AskQuestion`

When the **`AskQuestion`** tool is available in the session, **use it** for Finish gates instead of only free-form chat text:

- **Commit message** — One question with **multiple-choice options** (enumerate all; same set as **Chat fallback**):
  - **~Three concrete suggested messages** (each option is the full string for **`pipeline-finish.sh --commit-message`**).
  - **Other / manual** — user commits themselves — use **`--no-commit`**.
  - **Do not commit** — **`--no-commit`**; no orchestrator-created commit.
  - If the user selects **one of the suggested messages** (not **Other / manual** / **Do not commit**), record that exact string for **Finish script** (below).
- **Push** — One question: **Yes, I want to push** / **No, not now** (**binary** only). Map **Yes** → **`--push true`**, **No** → **`--push false`** for **Finish script**. **Yes** may still apply when **`--no-commit`** (sync existing commits).
- **Merge request** — One question: **Yes, create/update the MR** / **No**; if **yes**, collect **target branch** (user-entered), surface **`scripts/tools/mr-description-from-spec.sh`** output as the MR title/body, present it for review, then create/update the MR **via the GitLab MCP** (`mcp__GitLab__*`) — only after this explicit confirmation, never silently — see **`CLAUDE.md`**.

This gives the same **explicit confirmation** bar as prose prompts, with a clearer UX than walls of text.

##### Finish script (`pipeline-finish.sh`) — single Shell path for git + audit

After **both** commit intent **and** push intent are known (from **`AskQuestion`** or chat fallback), run **one** Shell invocation from the **workspace root**:

**`scripts/hooks/pipeline-finish.sh`** with flags per user choices:

| Outcome | Flags |
|--------|--------|
| User chose a **suggested** message | **`--commit-message '<exact>'`** or **`--commit-file <path>`** if newlines/quotes require it |
| **Do not commit** / **Other / manual** | **`--no-commit`** |
| Push **Yes** | **`--push true`** |
| Push **No** | **`--push false`** |

**Examples:** `scripts/hooks/pipeline-finish.sh --commit-message 'feat: …' --push false` · `scripts/hooks/pipeline-finish.sh --no-commit --push true`

The script runs brief **`git status`**, conditional **`git add`/`git commit`**, conditional **`git push`**, then **`python3 scripts/tools/audit-session-trace.py`** with skill defaults. **Do not** invoke **`audit-session-trace.py`** as a **separate** orchestrator Shell step. Optional **`--pre-audit-delay-seconds N`**; pass-through audit args after **`--`** (see **`pipeline-finish.sh --help`**).

##### Multi-root detach (after git + audit)

**When:** Only **after** **`scripts/hooks/pipeline-finish.sh`** has run (so **git** and **audit** are resolved inside that script). **Never** prompt for detach **before** **`pipeline-finish.sh`**.

**Condition:** Read **`docs/sessions/ACTIVE_SESSION`** for **`<active-session-id>`**. If **`docs/sessions/<active-session-id>/session.code-workspace`** **does not** exist, **skip** this subsection (no detach prompt).

**Prompt:** **`AskQuestion`** (preferred) or chat fallback — **one** binary question: **“Pipeline complete. Detach and archive workspace?”** — e.g. **Yes, detach and archive** / **No, keep the workspace file** (same bar as Push: explicit **Yes** only for the mutating path).

**On Yes:**

1. Remove **only** **`docs/sessions/<active-session-id>/session.code-workspace`**. Use **one** allowed Shell step: **`scripts/tools/session-memory.sh detach-workspace`** (**preferred**), **or** the **single-argument** **`rm`** exception in **Non‑negotiables** item **10** (multi-root detach). Do **not** delete **`attach-target.txt`**, **`current.md`**, **`artifacts/`**, or other session files.
2. Finalize session metadata: **`scripts/tools/session-memory.sh write`** with Timeline lines such as **`WORKSPACE_DETACHED: yes`** (and optional **`DETACH_CONFIRMED: yes`**). **Do not** treat this as a substitute for **`PIPELINE: COMPLETE`** — see **Finish order** below.

**On No:** Optionally **`session-memory.sh write`** **`DETACH_CONFIRMED: no`**.

**Completion output:** When the user chose **Yes**, state clearly that they should **close the multi-root workspace** and **reopen the orchestrator repository as a single folder** (or **File → Open Folder** on the framework root) so the IDE returns to an **orchestrator-only** view for the next **`/run`**.

**On failure** (hook error, non-zero exit): print **stderr**, suggest manual fix; still emit **Completion output** and note the failure. If **`pipeline-finish.sh`** failed, still offer **Multi-root detach** when **`session.code-workspace`** exists if the operator wants to archive the workspace file (optional **AskQuestion** — same **Yes** semantics).

**Limitation (Claude Code product):** `AskQuestion` is **most reliable in Plan mode**; in **Agent mode** availability can vary by Claude Code version and model (community requests: [AskQuestion in Agent mode](https://forum.cursor.com/t/allow-askquestion-tool-calls-in-agent-mode-or-any-mode/152517)). If **`AskQuestion` is not available** or fails, **fall back** to the numbered chat prompts below — do not block pipeline completion.

See **`docs/reference/cursor-mcp.md`** (AskQuestion section).

##### Chat fallback (when `AskQuestion` is unavailable)

1. **Commit message** — Offer **~three concrete suggestions**, plus **(D) Do not commit** and **(O) Other / manual**. Map outcomes to **`--commit-message`**, **`--commit-file`**, or **`--no-commit`** for **Finish script** (same semantics as **`AskQuestion`**).

2. **Push** — Binary yes/no → **`--push true`** / **`--push false`**.

3. **Merge request (GitLab)** — same confirmation flow as the **`AskQuestion`** MR branch: collect target branch, present the MR title/body, then create/update it **via the GitLab MCP** (`mcp__GitLab__*`) only after the user's explicit **Yes**. Never invoke mutating GitLab APIs silently, or assume an MR exists without that confirmation.

4. **Optional session-memory audit lines** (after the user has answered — for **human audit trails**, not for automation):  
   - `COMMIT_SUGGESTIONS: <brief list or “user chose custom”>`  
   - `PUSH_CONFIRMED: yes|no`  
   - `MR_TARGET_BRANCH: <name or n/a>`  
   - `MR_CONFIRMED: yes|no`  
   Append via **`scripts/tools/session-memory.sh write`** as **Timeline** entries (or free-form lines the user asked you to record).

5. **Delegation mode reminder** — Items **5–6** in the **Delegation header** apply: persona agents still **never** commit/push/MR; under orchestration they **do not** edit spec checkboxes or frontmatter — **`Task(do)`** applies **Proposed spec updates** after **`Task(scrum)`** gates (main session does **not** patch specs directly). The orchestrator may run **`scripts/hooks/pipeline-finish.sh`** only as described above; MR create/update is performed by the orchestrator via the **GitLab MCP** only after explicit user confirmation (see **Merge request** above).

6. **Multi-root detach** — After **`pipeline-finish.sh`**, when **`session.code-workspace`** exists, use **§ 9** — **Multi-root detach** (`AskQuestion` or **1** / **2** chat fallback: detach **Yes** / **No**).

**Session trace audit:** Handled **inside** **`pipeline-finish.sh`**. Details (**`context-audit.log`**, zero-match diagnostics, **`--pre-audit-delay-seconds`**, **`--prior-session-hints`**) — **`audit-session-trace.py --help`** and **`docs/run-pipeline-reference.md`** (**Finish script**, **Local auditing**).

**Finish order for `current.md` (successful run):** (1) optional step-**4** audit lines via **`session-memory.sh write`**; (2) **`scripts/hooks/pipeline-finish.sh`**; (3) when **`docs/sessions/<active-session-id>/session.code-workspace`** exists — **Multi-root detach** prompt, optional **`rm`** / **`detach-workspace`**, and **`WORKSPACE_DETACHED:`** / **`DETACH_CONFIRMED:`** writes; (4) **`session-memory.sh write "PIPELINE: COMPLETE"`** — **last** **`session-memory`** write for the run.

Then:

- **`scripts/tools/session-memory.sh write "PIPELINE: COMPLETE"`** **only** if all required steps succeeded or were explicitly skipped by flag — **after** **`pipeline-finish.sh`** and **after** optional **Multi-root detach** steps when applicable.
- Emit **Completion output** (below).

## Agent roster (who does what)

Full definitions: **`.claude/agents/<name>.md`** and **`CLAUDE.md`**. Orchestrated **`/run`** uses this subset most often:

| Agent / `Task(...)` | Role in pipeline |
|---------------------|------------------|
| **`pre-plan-triage`** | Classifies external sources + caps for two-wave MCP. |
| **`mcp-glean`**, **`mcp-arc`**, **`mcp-jira`**, **`mcp-confluence`**, **`mcp-gitlab`** | Bounded MCP specialists (main session only). |
| **`prd`**, **`spectech`**, **`tasks`** | Writes/amends `prd.md`, `spectech.md`, `tasks.md` in the ticket folder — the required orchestrator's front end (FR-3; no `Task(plan)`). |
| **`plan-reviewer`** | Spec quality gate — folder mode (cross-artifact PRD/spectech/tasks coverage) for this orchestrator's plan-segment inner loop (D2). |
| **`scrum`** | **Only** business gate that **authorizes** spec **`status`** / checkbox updates under orchestration (**`Task(do)`** applies file edits after **PROCEED**). Runs after plan segment, each **§ 6** batch, and **§ 7.1** post-QA. |
| **`dev`**, **`sre`**, **`data`** | Implementation (one **§ 5** phase per **`Task`**). |
| **`dev-reviewer`**, **`sre-reviewer`**, **`data-reviewer`** | Domain quality gates (**§ 6**). |
| **`qa`** | Cross-domain spec/security/integration review (**§ 7**); returns **Proposed spec updates** — **`Task(do)`** applies after **§ 7.1** scrum **PROCEED** (not before). |
| **`spec-validator`**, **`security-scanner`** | **Flat orchestration:** **not** nested **`Task(spec-validator)`** / **`Task(security-scanner)`** **from inside** **`Task(qa)`** or **`Task(*-reviewer)`**. Under orchestrated **`/run`**, the **main session** runs **`Task(security-scanner)`** in **§ 6** (phase **`phase-impl-delta`** → **`phase-<N>-security.md`**) **and again** in **§ 7.0** with **`Task(spec-validator)`** (**`security-scanner.md`** / **`spec-validator.md`** before **`Task(qa)`**) — **dual persistence** (see **§ 6**, **§ 7.0**, **`.claude/agents/security-scanner.md`**). The **`qa`** persona may **also** use session-local scripts or readonly tooling — see **`.claude/agents/qa.md`** (**Validators vs orchestrator `Task`**). |
| **`summary`** | Handoff / narrative after final scrum **PROCEED**; orchestrator passes **sliced** context per **§ 8**. |
| **`do`**, **`fix`**, **`codebase-explorer`**, **`kb`** | Escape hatches / supporting tools — **not** default **`/run`** steps unless the user’s goal requires them. |

## Parallelism

- **Pre-plan MCP gather (two waves):** After **`Task(pre-plan-triage)`**, **Wave 1:** parallel **`Task(mcp-glean)`** and **`Task(mcp-arc)`** **only** for sources triage lists (skip the whole wave if neither is listed). **Merge + gate.** **Wave 2:** parallel **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`** **only** when triage or the Wave 1 merged brief indicates need — **not** a default five-way parallel fan-out. Final merge → **`Task(prd)`**. Use **`description="…"`** per **§ 5 Task display names** when supported — see **Pre-plan context (optional MCP)**.
- **Phased specs:** **At most one** spec **`### Phase N:`** per **`Task(dev|sre|data)`**; **§ 6** (reviewers + **`Task(security-scanner)`** + scrum) for phase *k* **before** **§ 5** for phase *k+1*. Same domain in every phase ⇒ **separate** **`Task`** per phase, not one merged delegation.
- **Implementation (default):** Within a **single** phase, parallel `Task` + `Await` when the spec allows multiple domains — each **`Task(dev|sre|data)`** with **`description="…"`** per **§ 5 Task display names** when supported. **With `--manual`:** sequential domain tracks **within that phase** only (still use **`description`** when supported).
- **Implementation review (§ 6):** Per **phase**, parallel **`*-reviewer`** **`Task`** (as needed) **and** **one** **`Task(security-scanner)`** (**`phase-impl-delta`**), **`Await`**, **then** **`Task(scrum)`** — unless **`--skip impl-review`**. Persist **`phase-<N>-security.md`** per **§ 6**. **With `--manual`:** sequential per-track **`*-reviewer`** + **`Task(scrum)`** per **Manual step gates (`--manual`)**; still run **one** phase-level **`Task(security-scanner)`** in the § 6 wave with the **final** track’s **`*-reviewer`** for that phase (see **§ 6**).
- **QA:** **§ 7.0** — parallel **`Task(spec-validator)`** + **`Task(security-scanner)`** (`run_in_background` + **`Await`**) **before** **`Task(qa)`** when QA is not skipped; reports under **`artifacts/scanners/`**. Readonly validation **inside** **`Task(qa)`** may **additionally** run via **session-local** workflows (**scripts**, merged outputs) — **not** as **`Task(spec-validator)`** / **`Task(security-scanner)`** **nested from** **`Task(qa)`**. See **§ 7.0**, **Agent roster**, and **`.claude/agents/qa.md`**.

## Model plan

Follow **`references/model-plan.md`** and **`docs/run-pipeline-reference.md`** for `apply-models.sh`, strategies, escalation, and cost/budget warnings.

**Manual model mode (`use_manual_models: true` in `.claude/models.user.yml`):**

- **Do not** run per-step **`apply-models.sh <agent> <model-id>`** for the model plan or adaptive escalation.
- **Do not** run **`--restore-agent`** between steps (nothing to unwind; optional no-op `--restore` at end is harmless if you still snapshot at init).
- Still take **`--snapshot`** at init if you want a recorded baseline for logging or `--resume` notes; it reflects current frontmatter (typically already synced from `.claude/models.user.yml` via bulk apply).
- Seed **`model_plan`** from the user file conceptually (document in session memory as “manual model mode”); do not overwrite live frontmatter with dynamic picks.

## Invalid completion (do not accept your own output if)

- **`ORCHESTRATION_ABORTED`** or admission of implementing without Task.
- Skipped the **PRD/Spectech/Tasks segment** (`Task(prd)`→`Task(spectech)`→`Task(tasks)`), **qa**, **summary**, or reviews without matching **`--skip`**.
- Skipped **§ 6** (**implementation review** — **`*-reviewer`** + **`Task(security-scanner)`** + **`Task(scrum)`**) after any **§ 5** batch **without** **`--skip impl-review`** (or equivalent explicit user skip) — invalid; applies to **multi-phase** runs (no **§ 6** between phases) **and** **single-phase** runs (no **§ 6** before **§ 7**).
- **`PIPELINE: COMPLETE`** (or non-degraded completion) as if **§ 6** ran **without** a persisted **`phase-<N>-security.md`** under **`artifacts/scanners/`** when **`Task(security-scanner)`** **should** have run — **invalid**. **Exception:** **`--skip impl-review`** skips the **entire** § 6 (including **`Task(security-scanner)`** and § 6 **`Task(scrum)`**): **no** phase-level security artifact is required or produced; label completion **degraded** per **`--skip impl-review`** when implementation ran but those gates were skipped.
- Skipped **§ 7.0** (**QA prep wave** — parallel **`Task(spec-validator)`** + **`Task(security-scanner)`**, **`artifacts/scanners/`** persistence, injection into **`Task(qa)`**) when **`Task(qa)`** ran **without** **`--skip qa`** — **orchestration failure** (same class as other invalid-completion rules).
- Skipped **§ 7.1** (**final `Task(scrum)`** after **`Task(qa)`**) when **`Task(qa)`** ran **without** a matching **`--skip`** / documented override — invalid completion (or must be labeled **degraded** with **`FINAL_SCRUM_SKIPPED:`** in session memory).
- **Multi-phase single `Task(dev|sre|data)`** — one implementation **`Task`** covering **more than one** **`### Phase N:`** block.
- **Persona edited spec progress** (checkboxes **`[x]`**, **`status`**, **`last-updated`**) under **`[DELEGATION MODE: orchestrated]`** **without** going through **`Task(scrum)`** authorization — invalid; **`Task(do)`** applies spec updates **after** scrum **PROCEED** (main session **must not** patch specs directly).
- **Mostly `N/A`** for scores, models, and strategy together.
- **`PIPELINE: COMPLETE`** with “self-checked QA” / skipped real **`Task(qa)`** / **`Task(summary)`**.

If invalid: tell the user the pipeline was not valid; suggest re‑running from the failed step or restarting at **`/prd`**; do not “verify” the repo yourself as proof.

## Completion output template

Emit a block like:

```text
PIPELINE: COMPLETE
Spec: <path>
Mode: <auto|review>
Manual step gates: <off | on (--manual)>
Confidence threshold: <N>%
Branches: <branch per working repo>
Worktrees: <paths or none>
Gates: plan ✓ | plan-review ✓ | impl ✓ | impl-review ✓ | qa ✓ | final-scrum ✓ | summary ✓
Finish prompts: optional **`pipeline-finish.sh`** with **`--commit-message`** / **`--no-commit`** and **`--push true|false`** per user choices; MR suggestions only (no MR API by orchestrator)
Models used: <brief table>
Estimated cost: <optional>
QUESTION: <none or list>
APPROVAL_NEEDED: <none — user should review worktree / MR before merge>
```

## Error handling

- **Self-heal** (same escape hatch list as **`CLAUDE.md`**): **`/fix`**, **`/do`** ( **`Task(do)`** for mechanical work), **`/run --resume`** or re-run **`/run`**.
- On Task failure: **`scripts/tools/log-gate.sh failure <step> <error>`**; stop; suggest **`/fix`**, **`/do`**, **`/run --resume`**, or re-run **`/run`**.
- On **`QUESTION:`** / **`ASK_USER`** / **`APPROVAL_NEEDED:`** from a subagent: append the line to **`docs/sessions/<id>/current.md`** if helpful; surface to the user; the orchestrator may use **`AskQuestion`** when a structured choice helps. After the user answers, re‑invoke the relevant **`Task`** with the answer appended (or continue the pipeline per user direction).
- **Parallel implementation tracks (§ 5):** When **`Task(dev)`**, **`Task(sre)`**, and **`Task(data)`** run **in parallel** for a phase and **any** track returns **`QUESTION:`**, **`ASK_USER`**, or **`APPROVAL_NEEDED:`**, the orchestrator **pauses** pipeline progression for that phase **safely**: do **not** advance to **§ 6** (or the next track) as if all tracks succeeded — **await** user resolution or documented override. **Append** the escalation (which persona, which prefix, one-line summary) to **`docs/sessions/<id>/current.md`** via **`session-memory.sh write`**; **surface** it to the user before the next **`Task`**. Other parallel **`Task`** results may already be present — reconcile with the user before batching **§ 6** or re-running **§ 5** slices.

## Scripts you may invoke via Shell

**Orchestrator wrappers (prefer these; see Non‑negotiables item **10**):**

- **`scripts/hooks/pipeline-init.sh`** — **§ 2 Init** (`--resume`, optional `--slug`, `--targets`).
- **`scripts/tools/git-inspect.sh`** — **§ 1** read-only repo/branch/status/diff summary (orchestrator root by default; **`--repo <path>`** for the writable target clone or another git root).
- **`scripts/tools/log-gate.sh`** — **`GATE:`** / telemetry / **`FAILURE:`** (subcommands **`--help`**).
- **`scripts/hooks/pipeline-finish.sh`** — **§ 9 Finish** only: **`git add` / `git commit` / `git push`** (via flags after user consent) **and** **`audit-session-trace.py`** — **single** Finish path; **do not** call **`python3 scripts/tools/audit-session-trace.py`** separately.
- **`scripts/hooks/pipeline-commit.sh`** — mid-pipeline **`git add` / `git commit`** when **`commit_policy`** authorizes (**Commit policy**). **No** push. **No** audit.

**Other allowed tools:**

- **`scripts/tools/session-memory.sh`** — **`read`**, **`write`** for lines not covered by **`log-gate.sh`**, **`clear`**, **`prune`**, etc. (Init rotation is **inside** **`pipeline-init.sh`**, not duplicated here).
- **`scripts/tools/apply-models.sh`** — dynamic per-step overrides / restore (**Model plan**); Init **`--snapshot`** is already in **`pipeline-init.sh`**.
- **`scripts/tools/session-handoff.sh`** — pre-plan **`pre-plan/`** writes.
- **`scripts/tools/spec-status.sh`** (if present)
- **`scripts/tools/mr-description-from-spec.sh`** — **read-only** MR title/body for user paste; optional **`SUMMARY_PATH`**

**Narrow `git` exceptions:** **`git worktree add`**, **`git checkout -b`** / branch switch with **user-approved** names, or explicit user-requested operations **not** covered above. **Never** raw **`git status`**, **`git diff`**, **`git commit`**, or **`git push`** for orchestrator probes or Finish — use **`git-inspect.sh`**, **`pipeline-commit.sh`**, and **`pipeline-finish.sh`**.

Do **not** run destructive git (`reset --hard`, `clean -fdx`, force-push) unless the user explicitly asks. Do **not** run **`git push`** outside **`pipeline-finish.sh`** or without the Finish **Push** **`Yes`** mapped to **`--push true`**.
