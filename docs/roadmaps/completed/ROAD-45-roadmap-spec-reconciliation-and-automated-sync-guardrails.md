### ROAD-45: Roadmap-Spec Reconciliation & Automated Sync Guardrails

**Priority:** High  
**Category:** Operations / Quality  
**Status:** Completed — 2026-04-11  
**Complexity:** Medium  
**Dependencies:** ROAD-43, ROAD-44

#### Description

There is currently a "ghost backlog" where Architecture Specs are marked as `completed` in `docs/specs/`, but their corresponding Roadmap items remain `Planned` or `In-Progress`. This roadmap item reconciles that history and, more importantly, implements automated guardrails to ensure that no spec can ever reach `completed` status without its roadmap item being updated and archived.

#### Goal

- **Reconcile History:** Perform a one-time audit and move all roadmap files associated with `completed` specs to the `docs/roadmaps/completed/` directory.
- **Automated Guardrails:** Implement a linting check and a Scrum-gate validation that blocks pipeline completion if the Roadmap status does not match the Spec status.
- **Orchestration Rule:** Update the `run-pipeline` § 7.1 (Final Scrum) to mandate a roadmap status update as part of the "Definition of Done."

#### Detailed Workflow to Audit & Enforce

**1. The Reconciliation Script (`sync-roadmap-status.sh`)**
- Create a script that scans `docs/specs/*.md` for `status: completed`.
- It identifies the associated `ROAD-NN` and verifies if the file is in `docs/roadmaps/completed/`.
- If found in the active root, it updates the status to `Completed` and moves it to the archive folder.

**2. The Guardrail (Lint & QA)**
- Update `scripts/tools/lint-check.sh` to include a **Status-Sync Check**:
  - The script must cross-reference `docs/roadmaps/` and `docs/specs/`.
  - **Fail Case:** If a spec is `completed` but the roadmap is still in the active root or marked `Planned`, the linter throws a non-zero exit code.
- **Orchestrator Enforcement:** In `run-pipeline/SKILL.md`, the final `Task(scrum)` must explicitly verify the Roadmap sync before authorizing the `PIPELINE: COMPLETE` output.

**3. Mutation Delegation**
- When the Final Scrum returns `PROCEED`, the Main Agent must delegate a *single batched* `Task(do)` to:
  1. Set the Spec status to `completed`.
  2. Set the Roadmap status to `Completed`.
  3. Move the Roadmap file to the `completed/` subfolder.
- **Constraint:** The Main Agent is forbidden from editing either file directly to prevent accidental drift or roadmap corruption.

#### Deliverables

- [ ] **Sync Tool:** Create `scripts/tools/sync-roadmap-status.sh`.
- [ ] **Initial Cleanup:** Run the sync tool to clear the current "ghost backlog."
- [ ] **Linter Guardrail:** Update `lint-check.sh` with the Status-Sync Check to block future regressions.
- [ ] **Skill Update:** Update `run-pipeline/SKILL.md` to include Roadmap Archival in the § 9 Finish/Summary logic.

#### Notes

- This makes the `completed/` roadmap subfolder a "Source of Truth" for what has actually been delivered, verified by the existence of a corresponding completed spec.
