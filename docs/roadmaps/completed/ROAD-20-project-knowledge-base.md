### ROAD-20: Project Knowledge Base

**Priority:** Medium
**Category:** UX
**Status:** Completed
**Complexity:** Medium

#### Description

Persistent, condensed project context that agents consume instead of re-exploring codebases from scratch. Built by `/kb`, stored as a structured folder at `knowledge/{project}/` (tracked in git, shared across the team), and consumed by `/plan` and `/run`.

#### Deliverables

- [x] `/kb` agent (`.cursor/agents/kb.md`) — deep codebase analysis producing a structured knowledge base folder (`_index.md` + section files)
- [x] `knowledge-base` skill — output format: index, architecture, APIs, data models, deps, infra, conventions (selectively loaded)
- [x] `knowledge/` directory (tracked in git) with README
- [x] `/plan` integration: checks KB before delegating to codebase-explorer; warns on staleness >30 days
- [x] `/run` integration: warns if KB is missing (does not auto-invoke `/kb` — it is expensive and manual-only)
- [x] `/summary` integration: incrementally patches relevant KB section files after architecturally significant changes
- [x] Router rule updated with `/kb` trigger and Knowledge Base section

---
