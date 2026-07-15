### ROAD-53: Workspace Cleanliness & Symlink Eradication

**Priority:** High  
**Category:** Architecture / Tooling  
**Status:** Completed — 2026-04-11  
**Complexity:** Small  
**Dependencies:** ROAD-51

#### Description
During the ROAD-51 directory migration, implementation agents created root-level symlinks (`qa-artifacts` and `exploration`) for backward compatibility. Because these were created at the root, `.gitignore` failed to catch them, causing them to be tracked by Git. This roadmap item enforces a "Hard Cutover" policy for all directory migrations, permanently forbidding the creation of root-level symlinks for session data, and implementing git/linter guardrails to prevent it from happening again.

#### Goal
- **Eradicate Symlinks:** Delete the existing legacy symlinks and enforce the exclusive use of the canonical `artifacts/` paths established in ROAD-51.
- **Enforce Workspace Cleanliness:** Update Orchestrator rules to strictly forbid creating any session-related files, folders, or symlinks outside of `docs/sessions/`.
- **Git & Linter Guardrails:** Update `.gitignore` and add a check to the `lint-check.sh` script to fail if unauthorized root-level directories/symlinks are detected.

#### Detailed Workflow to Audit & Enforce

**1. The Hard Cutover (Cleanup)**
- Delete `qa-artifacts` and `exploration` symlinks from the workspace root.
- Do a final sweep of `scripts/` and `docs/` to ensure absolutely nothing relies on the old paths. (Everything must point to `docs/sessions/<ACTIVE_SESSION>/artifacts/...`).

**2. Guardrails & Orchestrator Policy**
- **Gitignore:** Update `.gitignore` to explicitly block `qa-artifacts/`, `exploration/`, and any other known legacy paths to catch rogue agent behavior immediately.
- **Linter Check:** Update `scripts/tools/lint-check.sh` to include a `find` command that asserts no symlinks exist at the workspace root that point into `docs/sessions/`.
- **Skill Update:** Add a strict instruction to `run-pipeline/SKILL.md` (and/or `.cursor/rules/`): *"Never create symlinks for backward compatibility during directory migrations. Use a hard cutover and update all consuming scripts to use the new canonical paths."*

#### Deliverables
- [ ] **Cleanup:** Remove root symlinks and update `.gitignore`.
- [ ] **Linter Update:** Add the workspace cleanliness assertion to `lint-check.sh`.
- [ ] **Skill Update:** Add the "Hard Cutover / No Symlinks" rule to the Orchestrator's non-negotiables.
- [ ] **Verification:** Run a test pipeline and run `git status` to ensure the working tree remains perfectly clean.