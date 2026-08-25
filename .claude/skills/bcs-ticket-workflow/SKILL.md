---
name: bcs-ticket-workflow
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
├── ticket.md         # optional issue definition + comments (when an intake step was used)
├── attachments/      # optional attachments (docs, diagrams, etc.)
├── prd.md            # product requirements (/prd)
├── spectech.md        # technical design, profile: lean|standard|full (/spectech)
├── tasks.md           # task list derived from prd.md + spectech.md (/tasks)
├── spec-review.md      # plan-segment (folder-mode) review outcome (plan-reviewer)
├── qa-report.md        # QA findings written by /qa (both standalone and orchestrated)
├── summary.md           # post-pipeline handoff narrative (/summary)
├── stop-*.md            # any stop-gate halt, with evidence
└── test-fixtures/      # payloads/XML/cjson/helpers created or used in repro and tests (not mixed with base docs; see bcs-repro skill)
```

- `<TICKET-KEY>` = Jira key as-is (e.g. `BG-10965`). Omit entirely when no ticket key is provided.
- `<slug>` = short, meaningful kebab-case description (e.g. `iss-swagger-redbc`).
- Use **today's date** (the date the folder is created) for `<YYYY-MM-DD>` — run `date +%Y-%m-%d`
  to get it. Never use the Jira ticket's creation date.
- `prd.md`, `spectech.md`, and `tasks.md` stay three separate files — never merged into one
  `spec.md`. `spectech.md`'s Lean/Standard/Full profile is the token/generality control.
- **`test-fixtures/`** holds JSON/XML/cjson/helpers created or used during repro and tests. Do not
  leave those files at the ticket root next to the base documents. See `bcs-repro` skill.

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
  `"intake": "done"`, `"explore": "skipped"` — any project-overlay keys) independent of the
  orchestrator's vocabulary. Do not force either vocabulary onto a step that doesn't apply — an
  open map lets both today's orchestrator and any future
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

- **Stop-gate:** when a step hits missing data, ambiguity, or conflict, it
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

## Workspace repo sync (precondition of any repo-wide read/scan)

Any step that **reads file content or greps across child repos for evidence** must sync the workspace
**first** — otherwise a read reflects whatever branch happened to be checked out (e.g. leftover
from an unrelated in-progress ticket), not the repo's actual current state. A working-tree read is
only as good as the branch it was taken from.

For every child repo in the workspace inventory (see the session-init hook's list):

1. `git -C <repo> status --porcelain` — if **dirty** (uncommitted changes), do **not** switch
   branches on that repo: treat it as another in-progress piece of work and leave it alone. Fall
   back to reading via `git show origin/<default-branch>:<path>` for that repo instead of the
   working tree, and record in `_notes.md` that this repo was skipped (dirty) and why.
2. Determine the default/base branch: `git -C <repo> symbolic-ref refs/remotes/origin/HEAD`
   (strip the `refs/remotes/origin/` prefix), or reuse `_state.json.base_branch` if already known
   for the ticket's own repo.
3. If clean: `git -C <repo> checkout <default-branch>` then `git -C <repo> pull --rebase`. Do not
   restore the previous branch afterward — leaving every repo on its up-to-date default branch is
   the intended end state, a clean baseline for whatever step runs next.
4. Record which repos were synced vs. skipped (and why) in `_notes.md` for traceability.

Never force a checkout/pull that would touch uncommitted or unpushed-but-diverging local work —
this is a shared, actively-used multirepo workspace; another branch's local state is presumptively
someone else's (or your own prior) in-progress work, never something to discard silently.


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

