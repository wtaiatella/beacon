### ROAD-08: Custom Linter Rules

**Priority:** Low
**Category:** Tooling
**Status:** Completed (2026-04-10)
**Complexity:** Small
**Dependencies:** None

#### Description

Workspace-specific lint rules that validate spec structure, task tag format, frontmatter conventions, and agent file consistency in CI.

#### Key Deliverables

- [x] Spec linter: validate frontmatter fields, section order, task tag format (`[domain]` / `[domain:repo]`) — `scripts/tools/lint-workspace-specs.sh`, job `workspace-spec-lint`
- [x] Agent linter: validate frontmatter fields, "Use when..." in descriptions — `scripts/tools/lint-workspace-agents.sh`, `agent-validation` job
- [x] CI integration via `.gitlab-ci.yml` extension

#### Notes

Start minimal to avoid noise. The CI pipeline already covers structural checks; this adds content-level validation. Run locally: `./scripts/tools/lint-workspace-content.sh` (see `CONTRIBUTING.md`).

---
