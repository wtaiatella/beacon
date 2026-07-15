### ROAD-21: Team Shared Conventions

**Priority:** High
**Category:** Tooling
**Status:** Planned
**Complexity:** Small
**Dependencies:** None

#### Description

A tracked directory where teams document shared coding conventions, API patterns, error handling standards, and naming rules. Agents reference these during implementation and review.

#### Key Deliverables

- [ ] `.cursor/conventions/` directory (or `docs/conventions/`) tracked in git
- [ ] Convention file format: markdown with clear, enforceable rules
- [ ] `/dev`, `/sre`, `/data` awareness: read conventions relevant to the target repo's stack before implementing
- [ ] `/qa` and reviewers: check implementation against documented conventions
- [ ] Starter examples: naming conventions, error handling patterns, API response format

#### Notes

Conventions are team-maintained via MRs like everything else. Start with 2-3 high-value conventions; don't over-document.

---
