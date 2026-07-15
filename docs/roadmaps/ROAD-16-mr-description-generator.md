### ROAD-16: MR Description Generator

**Priority:** Medium
**Category:** Tooling
**Status:** Planned
**Complexity:** Small
**Dependencies:** None

#### Description

Generate merge-request descriptions from spec, task checklist state, and git diff summary so MRs stay traceable to SDD artefacts.

#### Key Deliverables

- [ ] Skill or script template for MR body (title, summary, spec link, testing notes, reviewer scores)
- [ ] GitLab MR template integration (`/.gitlab/merge_request_templates/`)
- [ ] Optional branch-name-to-spec linking

#### Notes

Output is plain markdown, designed for GitLab MR descriptions. Adaptable to other platforms if needed.

---
