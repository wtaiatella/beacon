### ROAD-10: SIEM Audit Hook

**Priority:** Low
**Category:** Security
**Status:** Planned
**Complexity:** Medium
**Dependencies:** None

#### Description

Optional forwarding of audit events to a SIEM or log aggregator using structured JSON format for enterprise compliance.

#### Key Deliverables

- [ ] Adapter hook for structured audit export (JSON lines format)
- [ ] Configuration for endpoint, auth, and sampling
- [ ] Security notes (no secrets in payloads)

#### Notes

Off by default; requires network egress approval in most orgs.

---
