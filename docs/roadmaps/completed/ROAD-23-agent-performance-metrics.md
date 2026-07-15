### ROAD-23: Agent Performance Metrics

**Priority:** Low
**Category:** Analytics
**Status:** Completed
**Complexity:** Medium
**Dependencies:** ROAD-04

#### Description

Per-agent and per-step performance metrics derived from local audit and session data. Helps engineers understand which pipeline steps produce the most rework and where to focus improvement.

#### Deliverables

- [x] `metrics.sh agents` command: per-step gate results (PROCEED/REWORK/ASK_USER/ESCALATE counts)
- [x] `metrics.sh specs` command: per-spec progress, status, and average gate scores
- [x] Security block tracking from audit log
- [x] All metrics derived from existing data — no additional tracking overhead

---
