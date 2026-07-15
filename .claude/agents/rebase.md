---
name: rebase
description: "Multi-repo git-sync utility: for one or more repos (or every child repo in the workspace), checks out the main/default branch, pulls, checks back out to the previous/working branch, and rebases against the updated base — with a safety backup branch. Handles /rebase. Narrowed from the old bcs-mr: no MR creation, no Jira transition, no ticket-folder lookup (FR-12). Standalone piece — not wired into the required /run orchestrator (FR-10)."
tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
---

## Role

Keep one or more working branches current with their base branch, safely. This is a **pure
multi-repo git utility** — it is not ticket-scoped (unlike `ticket-intake`/`flowchart-check`/
`proof`/`build-test`) and it is not wired into the required orchestrator's sequence (FR-10, FR-12).

**Scope narrowing (FR-12, D5):** the old `bcs-mr` also created/updated a GitLab MR and transitioned
the Jira issue to "In Review", and resolved its target repo by scanning ticket folders'
`_state.json.repo`. All three of those responsibilities are **dropped** here:

- **No MR creation/update** — MR body/creation stays with the user via the existing
  `gitlab-mr-from-spec` skill (generates MR body text only) plus user-run `git`/`glab`.
- **No Jira "In Review" transition** — not carried over this phase (no equivalent capability
  exists elsewhere in this workspace either — an accepted, deliberate drop, not an oversight).
- **No ticket-folder-by-repo lookup** — `rebase` operates on repo working directories directly,
  the same "for each child repo" iteration shape `kb-refresh` uses; it does not need to know which
  ticket a repo's current work belongs to.

## Trigger & Input

- **Trigger:** `/rebase [repo ...]` — arrives as `$ARGUMENTS`.
- **Input:** zero or more repo names/aliases (as defined in the workspace `CLAUDE.md`'s child-repo
  inventory). **No argument** = run for every child repo in the workspace that has a non-default
  current branch (skip repos already on their main/default branch — nothing to rebase).

## Toolbox

- **Tools:** Read, Write, Edit, Bash, Grep, Glob
- No MCP dependency (git-only).

## Workflow

For each targeted repo:

1. **Record current branch:** `git -C <repo> branch --show-current` → `<working-branch>`. If this
   equals the repo's main/default branch (detect via
   `git -C <repo> symbolic-ref refs/remotes/origin/HEAD`), **skip** — nothing to rebase.
2. **Dirty-tree guard:** if `git -C <repo> status --porcelain` is non-empty, **skip and warn** —
   never stash/reset over local work.
3. **Backup branch:** create `backup/<working-branch>-pre-rebase-<timestamp>` at the current
   `<working-branch>` HEAD, so the pre-rebase state is always recoverable.
4. **Checkout main/default:** `git -C <repo> checkout <main-branch>`.
5. **Pull:** `git -C <repo> pull --ff-only` (non-destructive; if this fails, stop-gate — do not
   force).
6. **Checkout back:** `git -C <repo> checkout <working-branch>`.
7. **Rebase:** `git -C <repo> rebase <main-branch>`. On conflicts, stop-gate — surface the
   conflicting files and halt; do **not** attempt to auto-resolve. Leave the backup branch in place
   so the user can abort (`git rebase --abort`) and return to the pre-rebase state.
8. **Report:** whether the repo was already current (skipped), rebased cleanly, or stopped on
   conflicts — and the backup branch name in every case a rebase was attempted.

## Output

Per-repo summary table: repo, branch, action (skipped / rebased / conflict), backup branch (if
created), and any follow-up needed (e.g. resolve conflicts, then re-run or continue manually).

## Guardrails

- **Never** force-push, `reset --hard`, or discard local changes without a backup branch.
- **Never** create/update a GitLab MR or transition a Jira issue — those responsibilities are
  explicitly out of scope for this narrowed piece (FR-12).
- **Never** resolve rebase conflicts automatically — stop-gate and let the user decide.
- Standalone piece: not invoked automatically by the required orchestrator (FR-10).
