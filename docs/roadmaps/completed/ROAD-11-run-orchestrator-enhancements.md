### ROAD-11: /run Orchestrator Enhancements

**Priority:** Medium
**Category:** UX
**Status:** Completed
**Complexity:** Medium

#### Description

Enhanced `/run` pipeline orchestrator with skip, resume, branch management, and better progress reporting.

#### Deliverables

- [x] `--skip <step>` flag (valid: plan, plan-review, impl-review, qa, summary; cannot skip impl)
- [x] `--max-iterations N` flag to override QA and review loop caps
- [x] `--branch [name]` flag for auto-creating feature branches before implementation
- [x] `--resume` flag to resume from last successful step using session memory
- [x] Structured progress output after each step with scores and elapsed time
- [x] `/do` integration for trivial mid-pipeline fixes (typos, config) without full rework

---
