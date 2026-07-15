### ROAD-12: /run --sync flag

**Priority:** Low
**Category:** Integration
**Status:** Planned
**Complexity:** Small
**Dependencies:** ROAD-01 (Phase 2)

#### Description

Optional flag that invokes `/sync` at pipeline completion so Jira/Confluence stays in sync without a separate manual step. Requires the `/sync` subagent from ROAD-01 Phase 2.

#### Key Deliverables

- [ ] `--sync` flag parsing in `/run` orchestrator
- [ ] Graceful no-op or clear error if `/sync` subagent or Atlassian MCP is not configured
- [ ] Sync summary appended to `/run` completion output

---
