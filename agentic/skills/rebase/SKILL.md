---
name: rebase
description: "Multi-repo git-sync utility: for one or more repos (or every child repo in the workspace), checks out the main/default branch, pulls, checks back out to the previous/working branch, rebases against the updated base, and after a clean rebase pushes with --force-with-lease (or -u when there is no upstream). Safety backup branch is auto-deleted after a clean rebase (kept only on conflict/failure). Use when the user runs /rebase. No MR creation, no Jira transition, no ticket-folder lookup (FR-12). Standalone framework utility — not wired into the required /run orchestrator (FR-10)."
disable-model-invocation: true
---

# Rebase

Keep one or more working branches current with their base branch, safely. This is a **pure
multi-repo git utility** — it is not ticket-scoped and it is not wired into the required
orchestrator's sequence (FR-10, FR-12).

**Scope (FR-12):** git-sync only. Deliberately out of scope here:

- **No MR creation/update** — MR body/creation stays with the user via the `bcs-gitlab-mr-from-spec`
  skill (generates MR body text only) plus user-confirmed GitLab MCP actions. A git push that
  updates an already-open MR's source branch is git-sync, not an MR API mutation.
- **No Jira status transitions.**
- **No ticket-folder-by-repo lookup** — `rebase` operates on repo working directories directly,
  the same "for each child repo" iteration shape `kb-refresh` uses; it does not need to know which
  ticket a repo's current work belongs to.

Invoking `/rebase` **is** consent to push the rebased working branch (see step 9). Do not ask
again for push confirmation after a clean rebase.

## Trigger & Input

- **Trigger:** `/rebase [repo-name]` — arrives as `$ARGUMENTS`.
- **Two modes — determined solely by whether `$ARGUMENTS` is blank:**

  | Invocation | Scope |
  |---|---|
  | `/rebase` (no args) | **All** child repos detected in the workspace root |
  | `/rebase <repo-name>` | **Only** that repo (exact folder name or unambiguous prefix) |

- **No-arg mode:** discover child repos by listing first-level directories under the workspace root
  that contain a `.git/` folder (same detection the `session-init` hook uses). Iterate every one.
  For repos whose current branch **is** the main/default branch, skip the rebase step but still
  pull (`git pull --ff-only`) so the local main stays current — and report them as "pulled (on main)".
- **Named-repo mode:** if the name does not match any child repo, stop immediately and list the
  repos that do exist rather than silently doing nothing.

## Workflow

For each targeted repo:

1. **Record current branch:** `git -C <repo> branch --show-current` → `<working-branch>`. Detect
   main/default via `git -C <repo> symbolic-ref refs/remotes/origin/HEAD`.
   - If `<working-branch>` **equals** main: run steps 4–5 only (checkout is a no-op, just pull),
     then report as **"pulled (on main)"** and move to the next repo — no backup branch needed,
     **no push**.
   - Otherwise: proceed with the full rebase sequence (steps 2–10).
2. **Dirty-tree guard:** if `git -C <repo> status --porcelain` is non-empty, **skip and warn** —
   never stash/reset over local work. **Do not push.**
3. **Backup branch:** create `backup/<working-branch>-pre-rebase-<timestamp>` at the current
   `<working-branch>` HEAD, so the pre-rebase state is always recoverable.
4. **Checkout main/default:** `git -C <repo> checkout <main-branch>`.
5. **Pull:** `git -C <repo> pull --ff-only` (non-destructive; if this fails, stop-gate — do not
   force). **Do not push.**
6. **Checkout back:** `git -C <repo> checkout <working-branch>`.
7. **Rebase:** `git -C <repo> rebase <main-branch>`. On conflicts, stop-gate — surface the
   conflicting files and halt; do **not** attempt to auto-resolve. Leave the backup branch in place
   so the user can abort (`git rebase --abort`) and return to the pre-rebase state. **Do not push.**
8. **Backup cleanup:** if the rebase in step 7 completed cleanly (no conflicts), delete the backup
   branch created in step 3 (`git -C <repo> branch -D backup/<working-branch>-pre-rebase-<timestamp>`)
   — it is no longer needed once the working branch is safely rebased, and leaving it would
   accumulate one stale backup branch per run. On conflicts (or any stop-gate before the rebase
   finishes), **do not** delete it — it stays until the user resolves or aborts.
9. **Push (clean rebase only):** after step 7 succeeded with no conflicts, and only when
   `<working-branch>` is **not** a protected branch (`main` / `master` / `develop` / `development`
   / `release/*`):
   - If `<working-branch>` has **no** upstream: `git -C <repo> push -u origin <working-branch>`.
   - If it has an upstream: `git -C <repo> push --force-with-lease origin <working-branch>`.
   - **Never** `git push --force` / `-f` without lease.
   - If `--force-with-lease` is rejected (remote advanced), **stop-gate** for that repo — report
     the rejection and do **not** retry with `--force`.
   - If local already matches upstream after the rebase, the push is a no-op; report
     **pushed (already up to date)**.
10. **Report:** whether the repo was already current (skipped), rebased cleanly, pushed, stopped
    on conflicts, or failed the lease — and the backup branch name (noting it was deleted after a
    clean rebase, or is still present pending manual resolution).

## Output

Per-repo summary table: repo, branch, action (`pulled (on main)` / `rebased` / `pushed` /
`pushed (already up to date)` / `push failed — lease` / `conflict` / `skipped — dirty tree`),
backup branch (`deleted (clean rebase)` / `<branch-name> (kept — conflict)` / `n/a`), and any
follow-up needed (e.g. resolve conflicts, then re-run; or recover from a rejected lease).

## Guardrails

- **Never** `reset --hard`, or discard local changes without a backup branch.
- **Never** `git push --force` / `-f` without `--force-with-lease`.
- **Never** push to a protected branch (`main` / `master` / `develop` / `development` /
  `release/*`). On-main runs are pull-only.
- **Push after a clean rebase is required**, not optional: invoking `/rebase` is the consent.
  Do not prompt for a second Yes. Do **not** push on conflict, dirty-tree skip, failed pull, or
  when the working branch is the main/default.
- **Never** create/update a GitLab MR or transition a Jira issue — those responsibilities are
  explicitly out of scope for this narrowed piece (FR-12).
- **Never** resolve rebase conflicts automatically — stop-gate and let the user decide.
- **Never** delete the backup branch unless the rebase it protects completed cleanly — on
  conflicts or any earlier stop-gate, leave it in place for recovery.
- Standalone piece: not invoked automatically by the required orchestrator (FR-10).
