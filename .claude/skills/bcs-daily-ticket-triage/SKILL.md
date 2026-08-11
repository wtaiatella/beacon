---
name: bcs-daily-ticket-triage
description: >-
  Morning triage of all active ticket folders under docs/specs: checks analysis/implement
  status, new Jira comments, every GitLab MR (multi-repo), pipeline health, and branch sync
  with development; auto-rebases out-of-sync branches, auto-moves fully merged tickets to
  docs/specs/completed/, writes docs/specs/daily-status-YYYY-MM-DD.md, then monitors running
  pipelines via /loop. Use when the user runs /bcs-daily-ticket-triage, asks for daily ticket
  triage, morning ticket status, or to manage the growing docs/specs queue.
disable-model-invocation: true
---

# Daily ticket triage

Scan every **active** ticket folder under `docs/specs/`, produce one daily status markdown, take
authorized auto-actions (rebase + move to `completed/`), then watch in-flight pipelines.

**Not wired into `/run`.** Standalone morning operator skill.

## User-authorized auto-actions (this skill only)

| Action | Consent |
|---|---|
| `Task(rebase)` when a ticket branch is behind `development` | **Automatic — no confirmation** |
| Move folder to `docs/specs/completed/` when **all** MRs are `merged` | **Automatic — no confirmation** |
| `git push` / force-push / MR create / MR merge / Jira transition | **Never** — report only |

After a clean auto-rebase, report `rebase done — push needed (--force-with-lease)` per repo. Do not push.

## Trigger & input

- Slash: `/bcs-daily-ticket-triage [flags]`
- Flags (optional):
  - `--dry-run` — report only; skip rebase and folder moves
  - `--no-watch` — skip pipeline `/loop` monitor
  - `--ticket <KEY|folder>` — triage only that ticket
  - `--watch-interval <Nm>` — default `10m`
  - `--watch-timeout <Nm>` — default `90m`

You are the **main-session orchestrator**. Do not invent a subagent. Delegate only:
- `Task(rebase)` for out-of-sync repos
- MCP tools directly (or `Task(mcp-jira)` / `Task(mcp-gitlab)` if preferred for bounded briefs)

## Layout conventions

```
docs/specs/
├── <YYYY-MM-DD>-<TICKET>-<slug>/   # active tickets (scan these)
├── completed/                      # fully merged tickets (auto-moved here)
└── daily-status-YYYY-MM-DD.md      # triage output (overwrite same day)
```

- Ignore: `completed/`, files at the `docs/specs/` root (e.g. `ticketNotes.md`, `daily-status-*.md`),
  and any non-directory entries.
- Create `docs/specs/completed/` if missing.

## Per-ticket workflow

For each active folder (or the single `--ticket` target):

### 1. Load local state

Read `_state.json` (required). Optionally skim `_notes.md`, `impact-analysis.md`, `tasks.md`,
`summary.md`, `qa-report.md`.

**Analysis OK** when all present/true enough to proceed:
- intake/analysis: `impact-analysis.md` **or** `steps.ticket_intake == done` **or** `prd.md` exists
- plan: `prd.md` + `spectech.md` + `tasks.md` (or corresponding `steps.* == done`)

**Implementation OK** when `steps.implement == done` (or `tasks.md` shows implement complete /
`qa`/`summary` done). If unclear, mark `implementation: unknown` and continue.

### 2. Resolve **all** involved repos (multi-repo mandatory)

Build the repo set from, in order (union, de-dupe):

1. `_state.json.repos[]` if present (preferred)
2. `_state.json.repo` (single)
3. `impact-analysis.md` table rows marked involved / **Sim**
4. `tasks.md` `[domain:repo]` tags
5. Local branch discovery: for each workspace child repo with `.git/`, look for a branch matching
   the ticket key (`feat/<KEY>`, `fix/<KEY>`, or containing `<KEY>`)

Persist discoveries back into `_state.json` when useful:

```json
"repos": ["br-tax-engine", "br-tax-ui"],
"mrs": [
  { "repo": "br-tax-engine", "project_id": "br-tax-engine/br-tax-engine", "iid": 5903, "url": "…" }
]
```

Default `base_branch` is `development` unless `_state.json.base_branch` says otherwise.

**GitLab `project_id`** — derive from `git -C <repo> remote get-url origin` path
(e.g. `br-tax-engine/br-tax-engine`). Confirm via GitLab MCP `search_repositories` if unsure.

### 3. Jira comments / questions

If `ticket` / `jira_url` present:

1. Resolve Atlassian `cloudId` via `getAccessibleAtlassianResources` (cache for the run).
2. `getJiraIssue` with `fields` including `comment`, `status`, `updated`, `summary`, `issuelinks`.
3. Compare newest comments to `ticket.md` / last triage stamp / `_notes.md`.
4. Flag **Action needed** when there is a new comment, question (`?`), or @-mention since last run.

Do not reply on Jira from this skill.

### 3b. Blocked tickets — unblock discovery (mandatory)

When local notes / impact analysis / Jira status indicate a **block** (Waiting on Product,
blocked by another ticket, waiting on MR review elsewhere, external dependency):

1. Collect blocker refs from `_notes.md`, `impact-analysis.md`, Jira `issuelinks`, and comments
   (ticket keys `BG-#####`, MR `!N`, person/team names).
2. For each related **ticket**: fetch Jira status. Done/Closed/Shipped → candidate unblock signal.
3. For each related **MR**: check GitLab state (`merged` / `opened` / `closed`).
4. Report explicitly in the daily status under **Blocked / unblock check**:
   - `still blocked` — blocker ticket open **or** fix MR not merged
   - `partially unblocked` — e.g. related Jira Done but fix MR still open
   - `unblocked` — related work merged/closed; recommend next action (resume `/prd`, close as
     duplicate, reopen implement, etc.)
5. Prefer evidence links (Jira + MR URLs). Do not auto-close the blocked ticket.

### 4. GitLab MRs — **every repo**

For **each** involved repo:

1. Resolve source branch from `_state.json.branch` / `_state.json.branches.<repo>` / local branch
   matching the ticket.
2. `list_merge_requests` with `project_id`, `source_branch`, `state: all` (fallback: `search` =
   ticket key).
3. Record: **repo / GitLab project**, state (`opened`/`merged`/`closed`), IID, URL, title,
   target branch. Always name the project in the report (e.g. `br-tax-engine !5919`, never bare
   `!5919`).
4. If no MR found for a repo that has a feature branch → `MR missing`.
5. If MR `opened` → `list_merge_request_pipelines` → take **latest** pipeline status
   (`success` / `failed` / `running` / `pending` / `canceled` / `manual` / none).
   Treat `manual` as CI-passed-with-manual-gate (reviewable), **not** as failure.

**Always report implementation target:** which child repo(s) the work lives in
(`_state.json.repo` / `repos[]` / discovered), even when there is no MR yet
(e.g. `implementing in: br-tax-engine`).

**Ticket-level rollups (all MRs must agree):**

| Condition | Ticket status |
|---|---|
| Every involved repo has MR `merged` | **Completed** → auto-move folder (unless `--dry-run`) |
| Any MR `failed` pipeline | **Pipeline failed** |
| Any MR pipeline `running`/`pending` | **Watching** (add to watch list) |
| All open MRs have latest pipeline `success` or `manual`, not all merged | **Ready for review** |
| All open MRs pipeline green/manual **and** every branch synced with base | **Ready to merge** |
| Any branch behind base | **Needs rebase** → auto `Task(rebase)` |

A multi-repo ticket is **not** completed until **all** of its MRs are merged.

### 5. Branch sync + auto-rebase

For each involved repo with a non-base working branch:

```bash
git -C <repo> fetch origin
git -C <repo> merge-base --is-ancestor origin/<base_branch> <working-branch>
# or: git -C <repo> rev-list --left-right --count origin/<base_branch>...<working-branch>
```

- Behind base → queue `Task(rebase)` with **that repo name only** (named-repo mode).
- Dirty tree → do **not** rebase; report `skipped — dirty tree`.
- Rebase conflict → report conflict + backup branch; do not auto-resolve.
- After clean rebase → report push needed; do not push.

Batch independent repo rebases in parallel `Task(rebase)` calls when safe.

### 6. Auto-move to `completed/`

When **all** MRs for the ticket are `merged`:

```bash
mkdir -p docs/specs/completed
mv docs/specs/<folder> docs/specs/completed/
```

Update `_state.json` inside the moved folder: `"current_step": "completed"`, bump `updated_at`.
Append one line to that folder's `_notes.md` noting the move + MR IIDs.

Skip if `--dry-run`.

## Daily report

Write/overwrite:

`docs/specs/daily-status-YYYY-MM-DD.md`

Use today's date from `date +%Y-%m-%d`. Template:

```markdown
# Daily ticket triage — YYYY-MM-DD

Generated: <ISO-8601>
Flags: <flags or none>

## Action needed
| Ticket | Project(s) | Issue | Detail |
|---|---|---|---|
| BG-… | br-tax-engine | new Jira comment / pipeline failed / MR missing / rebase conflict / dirty tree | … |

## Blocked / unblock check
| Ticket | Blocker | Status | Evidence |
|---|---|---|---|
| BG-… | BG-10820 / MR br-tax-engine!5861 | still blocked / partially unblocked / unblocked | links + one-line reason |

## Ready for review
| Ticket | Project / MR | Pipelines | Sync |
|---|---|---|---|
| … | br-tax-engine !N, br-tax-ui !M | all success/manual | yes/no |

## Ready to merge
| Ticket | Project / MR | Notes |
|---|---|---|
| … | br-tax-engine !N | all pipelines green/manual + synced with development |

## Watching pipelines
| Ticket | Project | MR | Pipeline | Started |
|---|---|---|---|---|
| … | br-tax-engine | !N | running | … |

## Rebased this run
| Ticket | Project | Result | Push needed? |
|---|---|---|---|
| … | br-tax-engine | rebased / conflict / skipped | yes/no |

## Completed (moved to `completed/`)
| Ticket | Folder | Project / MRs |
|---|---|---|
| … | docs/specs/completed/… | br-tax-engine !N, br-tax-ui !M |

## Active inventory (other)
| Ticket | Project(s) | Analysis | Implement | MRs | Notes |
|---|---|---|---|---|---|
| … | br-tax-engine | ok/gap | ok/gap | … | in progress / blocked / … |

## Watcher
- Interval: 10m (or flag)
- Timeout: 90m
- Targets: <list or none>
```

Keep the report concise. Prefer links (Jira + MR URLs) over long prose.

## Pipeline watcher (`/loop`)

If any MR pipelines are `running`/`pending` and `--no-watch` was **not** set:

1. Follow the Cursor **loop** skill (Read `~/.cursor/skills-cursor/loop/SKILL.md`).
2. Arm a fixed loop every `--watch-interval` (default `10m`) with purpose `daily-triage-pipelines`.
3. On each tick: re-check **only** watched MRs via `list_merge_request_pipelines`.
4. When a pipeline finishes:
   - `success` → update daily-status: move ticket toward **Ready for review** / **Ready to merge**
     (re-check sync); tell the user.
   - `failed`/`canceled` → update **Action needed**; tell the user.
5. When the watch list is empty **or** `--watch-timeout` elapses, stop the loop and write a final
   update section `## Watcher finished` on the same daily-status file.

Do not open a second watcher if one for `daily-triage-pipelines` is already running.

## Execution order (main loop)

1. Parse flags; ensure `docs/specs/completed/` exists.
2. List active ticket folders.
3. For each folder: local → repos → Jira → MRs/pipelines → sync checks (collect rebase queue +
   move queue + watch list). Prefer parallel MCP/git reads across tickets when safe.
4. Run queued `Task(rebase)` calls (skip if `--dry-run`).
5. Perform completed moves (skip if `--dry-run`).
6. Write `docs/specs/daily-status-YYYY-MM-DD.md`.
7. Summarize to the user (point at the file; highlight Action needed + Ready to merge).
8. Start pipeline watcher if needed.

## Guardrails

- Read `bcs-ticket-workflow` if `_state.json` shape is unclear.
- AC-1: if both `context.json` and `_state.json` exist in a folder, stop that ticket and report.
- Never approve/merge MRs. Never transition Jira. Never auto-push.
- Never delete ticket folders — only `mv` into `completed/`.
- If GitLab or Jira MCP is unauthenticated, continue with local git/state checks and mark remote
  fields as `unavailable` — do not abort the whole run.
- Rebase stays within the `rebase` agent contract (backup branch, dirty-tree skip, no conflict
  auto-resolve).

## Examples

```text
/bcs-daily-ticket-triage
/bcs-daily-ticket-triage --dry-run
/bcs-daily-ticket-triage --ticket BG-11195
/bcs-daily-ticket-triage --no-watch --watch-interval 5m
```
