### ROAD-13: Advanced Confidence Scoring

**Priority:** Low
**Category:** Analytics
**Status:** Completed
**Complexity:** Large

#### Description

Multi-factor scoring model with per-domain risk weights, sub-score breakdowns, trend analysis, and calibration guidance.

#### Deliverables

- [x] `confidence-scoring` skill with full scoring model documentation
- [x] Per-domain risk weights configurable in spec YAML frontmatter (`confidence.weights`, `confidence.threshold`)
- [x] Reviewer output extensions: attention items (<60), weakest factor highlight, rework delta comparison
- [x] Trend analysis for `/scrum`: improving/flat/declining trajectory tracking
- [x] Calibration guidance by project type (internal 65%, customer-facing 75%, regulated 85%, security 90%)
- [x] `/plan` agent awareness: sets confidence weights based on risk assessment during spec creation

---
