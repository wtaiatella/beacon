---
name: ticket-workflow
description: "Shared conventions for the ticket-folder pipeline: ticket working folder layout, _state.json schema (open steps map), _notes.md, and the stop-gate / HITL gate rules. Read this before any step (the required orchestrator's /prd, /spectech, /tasks, /dev/sre/data/qa/scrum/summary, or a standalone ticket-scoped piece) touches a ticket folder's control file, so every piece shares the same state and folder contract."
---

# Ticket Workflow — shared conventions

A ticket (or any unit of work driven end to end through the agentic workspace) is tracked in one
**ticket working folder**. Every step reads and writes that single folder so the flow is
**resumable** and **auditable** — this skill is the single source of truth for that contract; the
individual pieces that touch a ticket folder (`/prd`, `/spectech`, `/tasks`, the required
orchestrator, and the ticket-scoped standalone pieces) reference it instead of duplicating it.

**This is the only control-file convention for the required orchestrator (A):** `context.json` is
retired entirely — no step in the unified workflow may create or update it.

## Ticket working folder

Under the workspace's `docs/specs/` root, one folder per ticket:

```
docs/specs/<YYYY-MM-DD>-<TICKET-KEY>-<slug>/      # with ticket key (e.g. BG-10965)
docs/specs/<YYYY-MM-DD>-<slug>/                   # without ticket key
├── _state.json      # machine state — the control file (schema below)
├── _notes.md        # human/agent notes: decisions + "where to resume" per step
├── ticket.md         # issue definition + comments (ticket-intake, when used)
├── attachments/      # downloaded attachments, incl. marked *.drawio (ticket-intake)
├── repro.md           # local before/after defect reproduction (repro, optional; feeds /prd)
├── prd.md            # product requirements (/prd)
├── spectech.md        # technical design, profile: lean|standard|full (/spectech)
├── tasks.md           # task list derived from prd.md + spectech.md (/tasks)
├── spec-review.md      # plan-segment (folder-mode) review outcome (plan-reviewer)
├── qa-report.md        # QA findings written by /qa (both standalone and orchestrated)
├── proof.md            # before/after practical proof (proof, optional)
└── stop-*.md            # any stop-gate halt, with evidence
```

- `<TICKET-KEY>` = Jira key as-is (e.g. `BG-10965`). Omit entirely when no ticket key is provided.
- `<slug>` = short, meaningful kebab-case description (e.g. `iss-swagger-redbc`).
- Use **today's date** (the date the folder is created) for `<YYYY-MM-DD>` — run `date +%Y-%m-%d`
  to get it. Never use the Jira ticket's creation date.
- `prd.md`, `spectech.md`, and `tasks.md` stay three separate files — never merged into one
  `spec.md`. `spectech.md`'s Lean/Standard/Full profile is the token/generality control.

## `_state.json` schema

```json
{
  "ticket": "BG-10965",
  "slug": "iss-swagger-redbc",
  "folder": "docs/specs/2026-07-15-BG-10965-iss-swagger-redbc",
  "jira_url": "https://avalara.atlassian.net/browse/BG-10965",
  "repo": "br-tax-engine",
  "base_branch": "development",
  "branch": "feat/BG-10965",
  "worktree": "",
  "current_step": "spectech",
  "steps": {
    "prd": "done",
    "spectech": "in_progress",
    "tasks": "pending",
    "implement": "pending",
    "code_review": "pending",
    "summary": "pending"
  },
  "spectech_profile": "standard",
  "gates": {
    "plan_segment": { "score": 89, "verdict": "PROCEED", "threshold": 80 },
    "code_review": { "dev_reviewer_score": 93, "qa_verdict": "APPROVED" }
  },
  "updated_at": "2026-07-15T12:00:00Z"
}
```

- `ticket` / `jira_url` are `null` or omitted when the folder was not created from a Jira key (a
  bare `/prd` invocation with an idea).
- **`steps` is an open, string-keyed map — not a fixed enum.** The required orchestrator (A) uses
  the six keys shown above (`prd`, `spectech`, `tasks`, `implement`, `code_review`, `summary`). A
  ticket-scoped standalone piece run outside the orchestrator may add its own key (e.g.
  `"flowchart_check": "skipped"`, `"ticket_intake": "done"`, `"repro": "done"`, `"build_test":
  "done"`, `"proof": "skipped"`) independent of the orchestrator's vocabulary. Do not force either
  vocabulary onto a step that doesn't apply — an open map lets both today's orchestrator and any future
  ticket-oriented orchestrator variant write their own step keys into the same file without schema
  churn.
- Step status values: `pending | in_progress | done | blocked | skipped`.
- Every step **updates its own status and `current_step`**, and bumps `updated_at`.
- On a stop-gate, set the step to `blocked` and record the `stop-*.md` filename in `_notes.md`.
- `gates` is optional, additive detail: machine-readable score/verdict per gate (e.g.
  `plan_segment` for the `/prd`→`/spectech`→`/tasks`→`plan-reviewer`→`scrum` gate, `code_review`
  for the implementation review gate).
- **Write-authority split:** `/prd`, `/spectech`, `/tasks` self-write their own `steps` entries
  directly (same self-write privilege as any other step). `implement`/`code_review`/`summary`
  entries are written by the orchestrator's `Task(do)` mechanism, in the same gate-authorized batch
  that already applies `tasks.md` checkbox updates after a `Task(scrum)` PROCEED — this prevents an
  implementation persona from self-certifying its own step `done`.

## Gate conventions

- **Stop-gate:** when a step hits missing data, ambiguity, conflict, or a flowchart deviation, it
  writes `stop-<step>.md` with concrete **evidence** in the ticket folder, sets the step to
  `blocked`, and halts. Never guess past a stop-gate.
- **Human-in-the-loop (HITL):** the step pauses and asks for the user's explicit OK before doing
  something outward-facing or hard to reverse — before implementing, before push/MR, before
  responding to review threads, and after the plan-segment review when acceptance is low (loop back
  to whichever of `prd`/`spectech`/`tasks` the reviewer's findings point at).
- **Out of scope:** MR **approval** is a team-specific process — no step here auto-approves.

## AC-1 regression guard: two control files detected

Any step that finds **both** `context.json` and `_state.json` present in the same ticket folder
must stop and surface the collision rather than picking one silently. This guards against
re-introducing the exact control-file ambiguity this convention exists to remove. Do not silently
prefer one file over the other, and do not delete either file automatically — report the collision
and ask the user which is authoritative (or whether the folder needs to be split).

## Multirepo & safety

- This workspace has independent child repos (see root `CLAUDE.md`). Any step touching code must
  use the `repo` from `_state.json` and run `git -C <repo> …`.
- Implementation happens on a branch in the user's existing working copy by default. Only use a
  `git worktree` if the user explicitly asks for one (record its path in `_state.json.worktree`).
- Non-destructive: never `reset --hard` / force-push without a backup branch.
- Secrets (Jira/GitLab/Sonar tokens) come from env/MCP config only — **never** written into the
  ticket folder.

## Branch setup (hard precondition of the implement step)

Before any code is written, create the feature branch **fresh from the up-to-date remote base** —
never start implementation on a stale local base or an unrelated in-progress branch:

1. `git -C <repo> checkout <base_branch>` then `git -C <repo> pull` — do not skip; the local base
   branch may be behind.
2. `git -C <repo> checkout -b feat/<TICKET>` **in the same working copy** the user already has open
   — do not use `git worktree add` for this unless the user explicitly asks for one.
3. Record `branch` in `_state.json` (leave `worktree` empty unless one was explicitly requested).

Applies per involved repo (multirepo). `/dev`/`/sre`/`/data` implement on the prepared branch; they
do not fetch, pull, or branch themselves, so the orchestrator/main thread must do this first.

## Flowchart marking convention (`flowchart-check`, when invoked)

Flowcharts (draw.io) are often huge and edited by many people, so `flowchart-check` does **not**
analyze the whole flow. Instead:

- The human drops the relevant `.drawio` file(s) into `attachments/` (the `.drawio` is plain,
  uncompressed mxGraph XML).
- The human marks the zone to check with a standard marker: a shape whose stroke/fill color is
  **`#CC0000`** and whose text is **`Region to check`** (case-insensitive) drawn around the region.
- `flowchart-check` finds that marker, computes its bounding box, and treats the labeled nodes
  whose center falls inside the box as the scoped conference zone — comparing only those against
  the code. It never reasons about nodes outside the marker.
- If no marker is found in a provided `.drawio`, stop-gate and ask the human to mark it (don't guess
  the zone).

## Progressive task tracking (`tasks.md`, during implementation)

`tasks.md` is a **live status document**, not a write-once checklist. Whoever executes a task from
it — `/dev`/`/sre`/`/data`, a ticket-scoped standalone piece, or the orchestrator relaying a
sub-agent's report — must update `tasks.md` **as each task completes**, not only in a final summary
pass:

- Mark the checkbox `[x]` immediately when a task is actually done and verified (tests passing,
  file changed as specified) — not when merely attempted.
- If what was actually implemented differs from the task's assumed detail, add a short `Result:` or
  `Note:` line under that task recording the real outcome.
- If a task turns out to be genuinely not done (deferred, blocked, or skipped), leave the checkbox
  unchecked and add a `Status:` line explaining why.
- Keep a small **Progress Log** table at the bottom of `tasks.md` (date, step, one-line result).

This keeps `tasks.md` trustworthy as the single place to check "what's actually done" for the
ticket, instead of requiring a manual reconciliation pass.

## Pecten-specific rule (br-tax-engine)

When a change touches a `pecten/models/**` YAML, the build step (`build-test`) regenerates
artifacts with `node pecten/index.js` and **keeps the full regeneration output** (do not
hand-strip unrelated drift).
