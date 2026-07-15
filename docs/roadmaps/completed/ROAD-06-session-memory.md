### ROAD-06: Session Memory

**Priority:** Low
**Category:** UX
**Status:** Completed
**Complexity:** Medium

#### Description

Lightweight session-scoped memory that persists decisions, open questions, and gate results across agent turns within a workspace session.

#### Deliverables

- [x] Session files under **`docs/sessions/`** (gitignored): **`ACTIVE_SESSION`** + **`docs/sessions/<session-id>/current.md`** (ROAD-35); stale files cleaned at next session start if untouched >24h
- [x] `scripts/tools/session-memory.sh` for read/write/clear/prune operations with typed categories (DECISION, QUESTION, GATE, context)
- [x] `session-init.sh` hook updated to inject session memory and prune stale sessions on start
- [x] `/run` orchestrator persists gate results to session memory for `--resume` support

---
