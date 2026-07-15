---
name: kb-refresh
description: "Incremental, multi-repo-aware knowledge refresh: for each child repo in the workspace, switch to its main branch, git pull (non-destructive), classify what changed since the last analysis, and refresh only the repos that need it; then hand off to kb-concentrator. Use before analyzing a ticket to ensure knowledge/ is current, or periodically to keep it fresh. Standalone — not wired into the required /run orchestrator (FR-10, FR-15)."
---

# KB Refresh

Bring `knowledge/` up to date with the current state of the workspace's **child repos**, then hand
off to `kb-concentrator`. This is **new, incremental** tooling distinct from `/kb`'s existing
manual, single-project, full-rebuild-per-run behavior (FR-15, DQ-1) — `kb-refresh` is
multi-repo-aware and only touches repos that actually changed.

**Standalone (FR-10, D9):** not a step of the required orchestrator's sequence — it operates on
`knowledge/` across the whole workspace, not one ticket folder, so it is exempt from the
`_state.json`/`_notes.md` per-ticket contract (spectech D9). Invoke it independently whenever you
want an incremental refresh.

## Repos in scope

Every child git repo under the workspace root (see root `CLAUDE.md`'s child-repo inventory).
Discover them dynamically, e.g.:

```bash
for d in */; do [ -d "${d}.git" ] && echo "${d%/}"; done
```

## Workflow

1. **For each child repo (non-destructive):**
   - If the working tree is dirty, **skip and warn** — never stash/reset over local work.
   - `git -C <repo> checkout <main-branch>` (the repo's default: `main`/`master`/`development` —
     detect via `git -C <repo> symbolic-ref refs/remotes/origin/HEAD`).
   - `git -C <repo> pull --ff-only`.
   - Compare current `HEAD` against the last analyzed hash recorded in `knowledge/<repo>/_index.md`
     (front-matter `last-analyzed`). Classify: `baseline-change`, `code-change`,
     `docs-only-change`, `no-impact-change`, or `unchanged`.
2. **Refresh only where needed:** for repos classified as changed, refresh that repo's KB. Use the
   existing **`/kb <repo>`** agent for a full (re)build on first onboarding or after major
   restructuring; for routine deltas, patch the affected section files under `knowledge/<repo>/`
   (mirrors how `/summary` optionally patches KB sections). Record the new `last-analyzed` hash.
3. **Interfaces:** keep cross-repo integration boundaries explicit in `knowledge/<repo>/interfaces.md`.
4. **Concentrator:** if the changes affect the system-level view, hand off to the
   **`kb-concentrator`** skill to update `knowledge/global-kb/`. Bootstrap `global-kb/` if absent.

## Guardrails

- **Non-destructive:** never discard local changes; skip dirty repos with a clear warning.
- Only refresh repos that actually changed — don't rebuild unchanged KBs.
- Keep KB assertions tied to concrete code paths.
- Standalone: not invoked automatically by the required orchestrator (FR-10).
