### ROAD-35: Session folder redesign

**Priority:** Medium  
**Category:** UX / Operations  
**Status:** Completed (2026-04-10) — session layout, pre-plan handoffs, two-wave staged pre-plan docs, auditing notes  
**Complexity:** Medium  
**Dependencies:** None  

#### Description

Evolve **`docs/sessions/`** from a single mutable **`current.md`** toward **timestamped session directories**, clearer **Glean / dev handoff artifacts**, and stronger **local auditing** of orchestration outcomes — without losing the lightweight, local-only model.

#### Deliverables

- [x] **Phase 1:** Roadmap status + **ROAD-36** entry (nested **`Task`** / subagent audit — **Completed**); optional **timestamp-inclusive spec filenames** documented in **`generate-spec`** and **CONTRIBUTING**
- [x] Timestamped per-session directories under **`docs/sessions/`** with predictable naming and retention (**`ACTIVE_SESSION`**, **`docs/sessions/<session-id>/current.md`** — see **`docs/run-pipeline-reference.md`**)
- [x] Conventions for **handoff artifacts** (pre-plan **`merged-brief.md`**, **`specialists/*.md`**, gate lines in **`current.md`**, Finish audit lines — see **`docs/run-pipeline-reference.md`**, **`docs/sessions/README.md`**)
- [x] **Auditing** notes (list session dirs, **`pre-plan/`** as proof of MCP gather, **`docs/audit.log`** / **`metrics.sh`**) — **`docs/run-pipeline-reference.md`** **Local auditing**

#### Notes

- **Staged pre-plan** (two-wave) and session layout: **`run-pipeline`** skill, **`docs/run-pipeline-reference.md`**, **`.cursor/agents/pre-plan-triage.md`**.

---

## Planned
