### ROAD-34: Collegiate Review

**Priority:** Medium
**Category:** Quality
**Status:** Planned
**Complexity:** Medium
**Dependencies:** Run enforcement layers (implemented)

Run 2-3 reviewers independently (optionally different models) on the same code. Aggregate scores for more robust gating. Cheap since reviewers use `composer-2`.

#### Deliverables

- [ ] Update review step to support `--collegiate N` flag
- [ ] Launch N reviewer instances per domain in parallel
- [ ] Aggregate scores (mean, median, or weighted)
- [ ] Document when collegiate review adds value vs cost

---
