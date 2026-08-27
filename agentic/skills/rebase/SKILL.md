---
name: rebase
description: "Multi-repo git-sync utility: for one or more repos (or every child repo in the workspace), optionally checks out/creates the ticket branch from origin, pulls the main/default branch, rebases the working branch onto it, and after a clean rebase pushes with --force-with-lease (or -u when there is no upstream). Safety backup branch is auto-deleted after a clean rebase (kept only on conflict/failure). Use when the user runs /rebase. No-arg /rebase infers a single ticket from this conversation, scopes to the repo(s) that actually changed (fallback: ticket _state.json), else rebases every child repo. No MR creation, no Jira transition. Standalone framework utility — not wired into the required /run orchestrator (FR-10)."
disable-model-invocation: true
---

# Rebase

Keep one or more working branches current with their base branch, safely. This is a **pure
multi-repo git utility** — it is not ticket-folder-scoped and it is not wired into the required
orchestrator's sequence (FR-10, FR-12).

**Scope (FR-12):** git-sync only. Deliberately out of scope here:

- **No MR creation/update** — MR body/creation stays with the user via the `bcs-gitlab-mr-from-spec`
  skill (generates MR body text only) plus user-confirmed GitLab MCP actions. A git push that
  updates an already-open MR's source branch is git-sync, not an MR API mutation.
- **No Jira status transitions.**
- **No ticket-folder lookup except no-arg fallback** — a Jira key in `$ARGUMENTS` is used only
  to **resolve a git branch** (see **Ticket branch**). Empty `$ARGUMENTS` may infer **at most
  one** key from **this conversation**, then scope repos as in **No-arg inference**. The only
  allowed ticket-folder read is that ticket's `_state.json` (`repo`, `branch`) when conversation
  evidence does not name the repo. Do not read `prd.md` / `spectech.md` / `tasks.md`.

Invoking `/rebase` **is** consent to (1) checkout/create a local tracking branch from an existing
`origin` branch when a ticket key is given, and (2) push the rebased working branch (see step 10).
Do not ask again for those confirmations after a clean run.

## Trigger & Input

- **Trigger:** `/rebase [repo ...] [ticket-key]` — arrives as `$ARGUMENTS`.
- Split `$ARGUMENTS` on whitespace. Classify each token independently (order does not matter):
  - **Ticket key:** matches `^[A-Za-z][A-Za-z0-9]+-[0-9]+$` (e.g. `BG-11320`, `AVT-102897`).
    At most **one**. More than one → stop-gate.
  - **Explicit branch:** contains `/` and is not a child-repo name (e.g. `feat/BG-11320`). Treat
    as the exact branch name; skip ticket-key globbing. At most **one** of {ticket key, explicit
    branch}.
  - **Repo name:** anything else — exact child-folder name or unambiguous prefix (`engine` →
    `br-tax-engine`). If it does not match any child repo, **stop immediately** and list the
    repos that do exist rather than silently doing nothing.

| Invocation | Scope | Working branch |
|---|---|---|
| `/rebase` (no args) | **No-arg inference** (below) | inferred ticket branch, or current branch in every child repo |
| `/rebase <repo>` | **Only** that repo | whatever is checked out (unchanged) — do **not** infer a ticket |
| `/rebase <repo> <ticket>` | **Only** that repo | ticket branch (checkout/create, then rebase) |
| `/rebase <ticket>` | **All** child repos that have a matching branch | that ticket branch in each; skip repos with no match |

### No-arg inference

When `$ARGUMENTS` is **empty**, decide ticket then **repo scope**. Do **not** scan other chats or
walk every ticket folder to pick a key.

**A. Ticket key**

1. Collect Jira keys matching `^[A-Za-z][A-Za-z0-9]+-[0-9]+$` that are the **subject** of this
   conversation (e.g. `/run BG-11374`, the in-progress ticket). Ignore keys that appear only as
   incidental file names, stash messages, or related-ticket asides.
2. **Zero** subject tickets, or **two or more** competing subjects → **all** child repos, current
   branch unchanged. Announce: `no single ticket — rebasing all child repos`. Stop here (do not
   read `_state.json`).
3. **Exactly one** subject ticket → continue to **B** (do **not** treat this as `/rebase <key>`
   across every clone).

**B. Repo scope** (only after A.3)

Resolve **which child repo(s)** to rebase, in order. The first source that yields one or more
existing child-folder names wins.

1. **Conversation changes (preferred).** Where did this ticket's work land?
   - Child-repo paths written or committed in this conversation (`br-tax-engine/…`).
   - Explicit repo the user/session treated as the implementation target.
   - Ignore incidental mentions (docs-only paths, stash of another ticket, related Jira keys).
   - Multi-repo tickets: include every child repo that actually received changes.
2. **Fallback — `_state.json`.** If step 1 is empty, locate **that key's** folder only
   (`docs/specs/*-<KEY>-*` or `docs/specs/*-<KEY>`). If **2+** folders match, stop-gate and list
   them. Read `_state.json` (`repo`, `branch` only):
   - `repo` must be an existing child folder (or unambiguous prefix, same as `/rebase engine`).
   - Empty / missing `repo` → treat as unresolved.
3. **Unresolved repo** → stop-gate. Do **not** rebase every clone. Ask the user which repo, or
   to pass `/rebase <repo> <ticket>`.

Announce, e.g. `inferred ticket BG-11374 from conversation; repo br-tax-engine (conversation
changes)` or `… repo br-tax-engine (_state.json)`.

**C. Branch** for each resolved repo: run **Ticket branch** with the inferred key. If
`_state.json.branch` is non-empty and that ref exists locally or on `origin`, use it as the
explicit branch (skip globbing). Never invent a branch that does not exist on `origin`.

Named-repo without a ticket (`/rebase engine`) is **not** this path: stay on whatever is
checked out in that repo. `/rebase <ticket>` (key in `$ARGUMENTS`) is unchanged: every child
repo that has a matching branch.

- **No-arg (all-repos fallback) / repo-only:** discover child repos by listing first-level
  directories under the workspace root that contain a `.git/` folder (same detection the
  `session-init` hook uses). For repos whose current branch **is** the main/default branch, skip
  the rebase step but still pull (`git pull --ff-only`) so the local main stays current — and
  report them as **"pulled (on main)"**.
- **Named-repo + ticket:** if the ticket branch cannot be resolved (missing or ambiguous),
  **stop-gate that repo** — do **not** fall back to whatever branch is currently checked out.
- **Ticket-only (all repos):** repos with no matching branch are `"skipped — no ticket branch"`.
  If **every** repo is skipped, stop and say no matching branch was found.

## Ticket branch

When a ticket key or explicit branch is present, **before** the rebase sequence, ensure the
targeted repo is on that branch and in sync with `origin`.

1. `git -C <repo> fetch origin` (so remote refs are current).
2. **Resolve `<ticket-branch>`:**
   - Explicit branch token → use it as-is (must exist locally or on `origin`).
   - Ticket key → collect local (`git branch --list`) and remote (`git branch -r`) names whose
     **last path segment** equals the key (case-insensitive), e.g. `feat/BG-11320`,
     `fix/BG-11320`, `BG-11320`. Also accept a last segment that **starts with** `KEY-` or
     `KEY_` (slug suffix) when there is no exact segment match.
   - **Ignore** names under `backup/`.
   - Strip the `origin/` prefix from remotes; compare unique short names.
   - **0 matches:** named-repo+ticket → stop-gate (list nearby branches). Ticket-only → skip
     that repo.
   - **2+ distinct short names:** stop-gate and list them — do not guess `feat/` vs `fix/`.
3. If HEAD is already `<ticket-branch>`, keep it.
4. If there is **no local** branch but `origin/<ticket-branch>` exists:
   `git -C <repo> checkout --track origin/<ticket-branch>`
   (creates the local branch at the remote tip). **Do not** invent a name that does not exist
   on `origin` (never `git checkout -b feat/BG-11320` from main).
5. If the local branch exists but HEAD is elsewhere: `git -C <repo> checkout <ticket-branch>`.
6. **Sync with origin:** `git -C <repo> pull --ff-only` (or fast-forward to `origin/<ticket-branch>`
   if upstream is not set but the remote ref exists). If ff-only fails (diverged), **stop-gate**
   — do not merge, reset, or rebase onto origin yet; leave the tree as-is.
7. That branch is now `<working-branch>` for the rest of the workflow.

Dirty tree (step 2 of the per-repo loop) still wins: never checkout/create over local work.

## Workflow

For each targeted repo:

1. **Record current branch** (before any checkout): `git -C <repo> branch --show-current`.
   Detect main/default via `git -C <repo> symbolic-ref refs/remotes/origin/HEAD`.
2. **Dirty-tree guard:** if `git -C <repo> status --porcelain` is non-empty, **skip and warn** —
   never stash/reset over local work. **Do not** checkout, create, rebase, or push.
3. **Ticket-branch ensure:** if a ticket key or explicit branch was given **or inferred from
   conversation** (no-arg path), run **Ticket branch** above and set `<working-branch>` to the
   resolved name. On the no-arg inferred-ticket path, only iterate the **resolved repo set**
   from **No-arg inference B** — not every clone. Otherwise `<working-branch>` stays the branch
   recorded in step 1.
   - If `<working-branch>` **equals** main: run steps 6–7 only (checkout is a no-op, just pull),
     then report as **"pulled (on main)"** and move to the next repo — no backup branch needed,
     **no push**. A ticket key must **not** resolve to the main/default branch; if it does,
     stop-gate.
   - Otherwise: proceed with the full rebase sequence (steps 4–11).
4. **Backup branch:** create `backup/<working-branch>-pre-rebase-<timestamp>` at the current
   `<working-branch>` HEAD, so the pre-rebase state is always recoverable.
5. **Checkout main/default:** `git -C <repo> checkout <main-branch>`.
6. **Pull:** `git -C <repo> pull --ff-only` (non-destructive; if this fails, stop-gate — do not
   force). **Do not push.**
7. **Checkout back:** `git -C <repo> checkout <working-branch>`.
8. **Rebase:** `git -C <repo> rebase <main-branch>`. On conflicts, stop-gate — surface the
   conflicting files and halt; do **not** attempt to auto-resolve. Leave the backup branch in place
   so the user can abort (`git rebase --abort`) and return to the pre-rebase state. **Do not push.**
9. **Backup cleanup:** if the rebase in step 8 completed cleanly (no conflicts), delete the backup
   branch created in step 4 (`git -C <repo> branch -D backup/<working-branch>-pre-rebase-<timestamp>`)
   — it is no longer needed once the working branch is safely rebased, and leaving it would
   accumulate one stale backup branch per run. On conflicts (or any stop-gate before the rebase
   finishes), **do not** delete it — it stays until the user resolves or aborts.
10. **Push (clean rebase only):** after step 8 succeeded with no conflicts, and only when
    `<working-branch>` is **not** a protected branch (`main` / `master` / `develop` / `development`
    / `release/*`):
    - If `<working-branch>` has **no** upstream: `git -C <repo> push -u origin <working-branch>`.
    - If it has an upstream: `git -C <repo> push --force-with-lease origin <working-branch>`.
    - **Never** `git push --force` / `-f` without lease.
    - If `--force-with-lease` is rejected (remote advanced), **stop-gate** for that repo — report
      the rejection and do **not** retry with `--force`.
    - If local already matches upstream after the rebase, the push is a no-op; report
      **pushed (already up to date)**.
11. **Report:** whether the repo was already current (skipped), had a local branch created from
    origin, rebased cleanly, pushed, stopped on conflicts, or failed the lease — and the backup
    branch name (noting it was deleted after a clean rebase, or is still present pending manual
    resolution).

## Output

Per-repo summary table: repo, branch, action (`pulled (on main)` / `checked out` /
`created local from origin` / `rebased` / `pushed` / `pushed (already up to date)` /
`push failed — lease` / `conflict` / `skipped — dirty tree` / `skipped — no ticket branch` /
`stop — ambiguous ticket branch` / `stop — unresolved repo`), backup branch (`deleted (clean rebase)` /
`<branch-name> (kept — conflict)` / `n/a`), and any follow-up needed (e.g. resolve conflicts,
then re-run; recover from a rejected lease; pick among ambiguous branches).

## Guardrails

- **Never** `reset --hard`, or discard local changes without a backup branch.
- **Never** `git push --force` / `-f` without `--force-with-lease`.
- **Never** push to a protected branch (`main` / `master` / `develop` / `development` /
  `release/*`). On-main runs are pull-only.
- **Never** invent a ticket branch that does not exist on `origin`. Create local **only** by
  tracking an existing remote branch.
- **Never** fall back to the currently checked-out branch when a ticket key was given and
  resolution failed.
- **Push after a clean rebase is required**, not optional: invoking `/rebase` is the consent.
  Do not prompt for a second Yes. Do **not** push on conflict, dirty-tree skip, failed pull, or
  when the working branch is the main/default.
- **Never** create/update a GitLab MR or transition a Jira issue — those responsibilities are
  explicitly out of scope for this narrowed piece (FR-12).
- **Never** resolve rebase conflicts automatically — stop-gate and let the user decide.
- **Never** delete the backup branch unless the rebase it protects completed cleanly — on
  conflicts or any earlier stop-gate, leave it in place for recovery.
- Standalone piece: not invoked automatically by the required orchestrator (FR-10).
