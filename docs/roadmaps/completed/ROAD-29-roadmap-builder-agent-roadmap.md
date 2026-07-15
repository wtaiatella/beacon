### ROAD-29: Roadmap Builder Agent (/roadmap)

**Priority:** High
**Category:** Tooling
**Status:** Completed (2026-04-10)
**Complexity:** Large
**Dependencies:** None

#### Description

A new agent that transforms architecture documents, ideas, or high-level visions into structured, prioritized roadmap items. Fills the gap between "I have an idea" and "I have a spec to implement" — currently, roadmap items are hand-written and the leap from vision to actionable backlog is manual.

The agent supports multiple scenarios: greenfield projects (build from scratch), large refactoring or migration (analyze current state, define target, create incremental steps), and in-progress work (assess what's done, identify gaps, create items for remaining work).

When `/run` later picks up a roadmap item, `/plan` should check implementation status before planning — if the item is already fully implemented, mark it complete and move on; if partially done, plan only the gaps.

#### Phase 1: Core Agent

- [x] `/roadmap` agent (`.cursor/agents/roadmap.md`) with `model: default`
- [x] Input: `<target-dirs or doc-path> [idea or vision description]`
- [x] Discovery phase: analyze target codebase structure, existing roadmap, dependencies, and architectural patterns (delegate to `codebase-explorer` or consume KB if available)
- [x] Output: structured roadmap items in `roadmap.md` format (ROAD-XX numbering, priority, category, status, complexity, dependencies, description, deliverables, notes)
- [x] Auto-assign ROAD numbers by reading existing roadmap and incrementing
- [x] Dependency detection: identify which items must precede others and set `Dependencies:` fields
- [x] Complexity estimation: Small / Medium / Large based on scope and file count analysis

#### Phase 2: Scenario Support

- [x] **Greenfield mode:** Given an architecture document or idea, break down the full build into phased roadmap items. Group by domain (`[dev]`, `[sre]`, `[data]`) where applicable.
- [x] **Migration/refactoring mode:** Given a target directory and a vision (e.g., "migrate from REST to gRPC"), analyze current state, define target state, and create incremental migration steps that can be executed independently.
- [x] **Gap analysis mode:** Given a target directory and an existing roadmap or architecture doc, compare what exists vs. what's specified. Create items only for gaps. Mark already-completed items.
- [x] **Enhancement mode:** Given an existing feature and improvement goals, create items for iterative improvement without breaking existing functionality.

#### Phase 3: /plan and /run Integration

- [x] `/plan` integration: when planning a roadmap item, check if the target code already implements the item (fully or partially). If fully implemented, recommend marking complete. If partially done, plan only the gaps.
- [x] `/run` integration: `/run` can accept a ROAD-XX reference directly and resolve it to the roadmap entry for context during planning
- [x] Roadmap validation: `/roadmap --validate` mode that checks for circular dependencies, orphaned items, stale statuses, and missing deliverables
- [x] Router rule update: add `/roadmap` to Available Personas table

#### Phase 4: Multi-Project Support

- [x] Support generating roadmap items for external projects (not just the agentic-workspace itself)
- [x] Configurable roadmap root directory (default: `docs/roadmaps`, overridable for target projects via `ROADMAP_FILE`)
- [x] Cross-project dependency tracking when the vision spans multiple repositories

#### Notes

- **Shipped:** `docs/specs/2026-04-10-road-29-roadmap-builder-agent-spec.md` — scripts `roadmap-next.sh`, `roadmap-validate.sh`, tests `scripts/tools/tests/roadmap-tools-selftest.sh`; router and run-pipeline docs updated.
- The agent should produce roadmap items, not specs. Specs are generated later by `/plan` when an item is picked up for implementation.
- Keep items at the right granularity: each item should be implementable in a single `/run` pipeline (1-3 days of agent work). If an item is too large, the agent should break it into sub-items.
- The agent should read existing completed items to understand what infrastructure is already available (e.g., "audit log exists, session memory exists, confidence scoring exists").
- For the agentic-workspace itself, the agent should understand the BMAD+SDD framework and produce items that align with the workspace's patterns (hooks, agents, skills, router rule).

---
