### ROAD-42: Session Folder Rotation Fix & Task(do) Spec Patching

**Priority:** High
**Category:** Bug Fix / Orchestration
**Status:** Completed
**Complexity:** Medium
**Dependencies:** ROAD-35

#### Description

Two critical orchestration leaks were identified during pipeline execution. First, the session initialization logic is failing to rotate the `ACTIVE_SESSION` pointer, causing new `/run` invocations to overwrite legacy session folders and `merged-brief.md` files. Second, the Main Agent is directly editing spec files (and mistakenly touching roadmap files) to apply "Proposed completions," violating the strict "orchestrators only orchestrate" rule.

#### Goal

- **Session Rotation:** Ensure every new `/run` invocation forces the creation of a fresh timestamped directory in `docs/sessions/` and correctly updates `ACTIVE_SESSION`.
- **Delegated Spec Patching:** Refactor the Orchestrator so it NEVER edits files directly. When `Task(scrum)` returns `PROCEED`, the Main Agent must batch all "Proposed completions" and delegate them to `Task(do)` with explicit boundaries to *only* edit the target spec file.

#### Deliverables

- [ ] **Fix Session Init:** Audit and patch the script (e.g., `session-init.sh` or `session-memory.sh`) responsible for session creation so it strictly enforces a new `YYYY-MM-DDTHHMMSSZ` folder per `/run` unless `--resume` is passed.
- [ ] **Task(do) Patching Logic:** Update `run-pipeline/SKILL.md`. When a Scrum gate passes, the Main Agent must invoke `Task(do, "Apply these proposed completions to docs/specs/<spec-slug>.md ONLY. Do not touch any other files.")`.
- [ ] **Guardrail Enforcement:** Add a hard rule to `run-pipeline/SKILL.md` explicitly forbidding the Main Agent from directly modifying markdown files (especially roadmap files under `docs/roadmaps/`).
- [ ] **Verification:** Run a test pipeline. Verify a new session folder is created, and prove that `Task(do)` handles the spec updates without bleeding edits into other workspace files.

---
