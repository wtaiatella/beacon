### ROAD-32: Best-of-N Planning

**Priority:** Medium
**Category:** Quality
**Status:** Planned
**Complexity:** Medium
**Dependencies:** Run enforcement layers (implemented)

Launch 2-3 `/plan` agents (optionally with different models) in parallel worktrees. Have `plan-reviewer` score all specs independently. Pick the highest-scoring spec. Doubles/triples planning cost but may produce better specs for complex features.

#### Deliverables

- [ ] Update `/run` workflow to support `--best-of-n-plan` flag
- [ ] Launch parallel `/plan` instances from the main agent with `Task` + `run_in_background: true`
- [ ] Score all specs via `plan-reviewer`, pick the best
- [ ] Document cost implications and when to use

---
