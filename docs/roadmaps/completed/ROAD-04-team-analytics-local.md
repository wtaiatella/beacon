### ROAD-04: Team Analytics (Local)

**Priority:** Medium
**Category:** Analytics
**Status:** Completed
**Complexity:** Medium

#### Description

Local-only pipeline and agent metrics aggregated from audit logs and session memory. Engineers can inspect their own pipeline health, gate outcomes, and rework patterns without any data leaving the machine.

#### Deliverables

- [x] `scripts/tools/metrics.sh` with 5 commands: `overview`, `agents`, `specs`, `gates`, `sessions`
- [x] Aggregates from `docs/audit.log` (sessions, security blocks) and `docs/sessions/` (gate decisions, scores, pipeline outcomes)
- [x] First-pass rate calculation (PROCEED / total gates)
- [x] Per-step gate decision breakdown (plan, impl, qa — PROCEED/REWORK/ASK_USER/ESCALATE)
- [x] All data local-only — nothing leaves the machine

---
