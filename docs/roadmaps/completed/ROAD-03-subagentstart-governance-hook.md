### ROAD-03: subagentStart Governance Hook

**Priority:** Medium
**Category:** Security
**Status:** Completed
**Complexity:** Small

#### Description

Branch governance hook that blocks write-capable agents on protected branches, enforcing policy consistently across all personas and `/run` pipelines.

#### Deliverables

- [x] `subagentStart` hook (`subagent-gate.sh`): checks child repos (not workspace root) and blocks non-readonly agents when any child repo is on `main`, `master`, `develop`, or `release/*`. No override — agents never deploy; all deployments go through CI/CD.

---
