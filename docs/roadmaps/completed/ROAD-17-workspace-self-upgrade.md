### ROAD-17: Workspace Self-Upgrade

**Priority:** Medium
**Category:** Infrastructure
**Status:** Completed
**Complexity:** Medium

#### Description

Documented and scripted upgrade path for consuming repos from the upstream agentic-workspace.

#### Deliverables

- [x] `scripts/upgrade.sh`: `--check` (compare), `--apply` (merge with backup branch and conflict guidance), default mode (status summary)
- [x] `YY.M.RELEASE` versioning via git tags (manual CI job on main)
- [x] Conflict hotspot guidance for `.cursor/rules/`, `.cursor/agents/`, `.cursor/hooks.json`

---
