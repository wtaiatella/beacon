---
name: confidence-scoring
description: "Advanced confidence scoring model for reviewers and /scrum. Per-domain weights, sub-scores, trend analysis, and calibration guidance."
---

# Confidence Scoring

## When to Use

- When any reviewer (`dev-reviewer`, `sre-reviewer`, `data-reviewer`, `plan-reviewer`) produces confidence scores
- When `/scrum` needs to interpret or aggregate scores at quality gates
- When calibrating scoring thresholds for a spec's risk profile

This model supersedes the simple threshold check with weighted, multi-factor scoring, trend tracking, and calibration guidance.

## Scoring Model

Every reviewer produces **6 confidence factors**:

| Factor | Weight | Description |
|--------|--------|-------------|
| Spec alignment | **20%** (fixed) | How well the output matches the spec's intent and acceptance criteria |
| Domain factor 1 | shares 80% | First domain-specific quality dimension |
| Domain factor 2 | shares 80% | Second domain-specific quality dimension |
| Domain factor 3 | shares 80% | Third domain-specific quality dimension |
| Domain factor 4 | shares 80% | Fourth domain-specific quality dimension |
| Domain factor 5 | shares 80% | Fifth domain-specific quality dimension |

The 5 domain factors share the remaining **80%** equally (16% each by default). Each factor is scored 0–100.

**Overall score** = `(spec_alignment × 0.20) + (mean(domain_factors) × 0.80)`

## Per-Domain Risk Weights

Specs can declare domain risk weights in YAML frontmatter that `/scrum` uses when aggregating across domains:

```yaml
---
status: draft
confidence:
  weights:
    dev: 1.0
    sre: 1.5    # infra is higher-risk for this spec
    data: 2.0   # data changes are critical
  threshold: 95  # override default 90%
---
```

### Rules

- If **no weights declared**, all domains default to **1.0** (equal weight).
- Higher weight = **stricter scoring** for that domain. `/scrum` multiplies domain score by weight when computing the aggregate.
- Aggregate formula: `sum(domain_score_i × weight_i) / sum(weight_i)`
- The `threshold` field overrides the workspace default of 90%. Reviewers and `/scrum` must respect it.
- When a reviewer sees custom weights in the spec frontmatter, it should **note the domain weight** in its report header (e.g., "Domain weight: 1.5× (elevated)").

## Sub-Score Breakdown

Reviewers already report each factor individually. In addition:

### Attention Items

Flag any factor scoring **below 60** as an **attention item**. Format in findings:

```
⚠ Attention: {factor_name} scored {score}/100 (below 60 threshold)
  Evidence: {brief justification}
```

### Weakest Factor

Highlight the **single weakest factor** in the report header, immediately after the overall score line:

```
### Score: 72% (Needs Attention)
Weakest factor: Test coverage (45/100)
```

### Rework Iteration Comparison

When this review is a **rework iteration** (the reviewer has access to a prior score, via delegation context or session memory):

- Compare current score to previous iteration
- Note the delta for each changed factor
- Format: `"Score improved from 62% to 78% (+16%)"`
- If individual factors regressed, call them out: `"⚠ Error handling regressed: 80 → 65 (-15)"`

## Trend Analysis (for /scrum)

When `/scrum` has access to multiple gate results (via session memory, delegation context, or accumulated reports):

### Score Trajectory

Track the direction across iterations:

| Trajectory | Pattern | Interpretation | Recommended Action |
|------------|---------|----------------|--------------------|
| **Improving** | Each iteration scores higher | Rework is effective | Continue current approach |
| **Flat** | Score stays within ±5% across iterations | Wrong area being fixed | Re-read reviewer findings carefully; ensure rework addresses the actual flagged issues |
| **Declining** | Score drops after rework | Likely spec ambiguity or cascading issues | Recommend `/plan` amendment to clarify spec before further rework |

### Reporting Format

```
Trend: Improving (62% → 71% → 78%)
Assessment: Rework is converging. Proceed with current approach.
```

or

```
Trend: Flat (65% → 63% → 66%)
Assessment: Score is not converging after 3 iterations. Likely cause: rework is not
targeting the flagged issues. Recommendation: re-read reviewer findings and confirm
the correct files/areas are being modified.
```

## Calibration Guidance

### Recommended Starting Thresholds by Project Type

| Project Type | Threshold | Rationale |
|-------------|-----------|-----------|
| Internal tools | **65%** | Lower blast radius; speed matters |
| Customer-facing apps | **90%** (default) | Below this, the gate reworks once before asking the user |
| Financial / regulated | **85%** | Compliance requirements; audit trail |
| Security-critical | **90%** | Zero-tolerance for security gaps |

### Monthly Calibration Review

Teams should review QA outcomes monthly and adjust thresholds:

- **Specs that passed review but failed QA** → thresholds are too low. Raise by 5–10%.
- **Specs that required >1 rework loop** → specs are unclear. Fix upstream (`/plan` quality) rather than tightening downstream thresholds.
- **Specs that consistently pass on first review** → thresholds may be too low, or the team is strong. Validate by checking QA outcomes.

### Anti-Patterns

| Signal | Root Cause | Fix |
|--------|-----------|-----|
| All specs score 90%+ but QA finds issues | Reviewer is too lenient or factors are wrong | Recalibrate factor definitions; add domain checks |
| All specs score <60% | Reviewer is too strict or specs are poor quality | Review spec templates; adjust factor expectations |
| Same factor always lowest | Systemic gap (e.g., tests always weak) | Address via team process, not threshold adjustment |
| Scores fluctuate wildly between iterations | Inconsistent review criteria | Standardize evidence requirements for each factor level |

## Model-Aware Scoring

When a reviewer knows the model tier used for the work being reviewed (via delegation context or session memory), factor this into the scoring narrative and recommendations.

### Model Tier Context

Reviewers should note the model tier in their report header when known:

```
### Score: 68% (Needs Attention)
Weakest factor: Error handling (52/100)
Model tier: economy (e.g. composer-2)
```

### Escalation Recommendations

When a score falls in the **50–74% range** (ASK_USER zone) and the work was produced by a lower-tier model (nano, economy, or standard), include an escalation recommendation before suggesting rework:

```
⚡ Model escalation recommended: Score 68% on economy-tier model.
   Recommend retry on standard tier before rework — reasoning-intensive
   factors (error handling, edge cases) often improve with higher-capability models.
```

### When to Recommend Escalation vs Rework

| Signal | Recommendation |
|---|---|
| Weak factors are reasoning-intensive (architecture, edge cases, security) | Escalate model — higher reasoning capability directly addresses these |
| Weak factors are content-based (missing tests, wrong API, spec misread) | Rework — model capability won't fix factual errors or missing content |
| Score is below 50% regardless of model | Rework — the gap is too large for model escalation alone |
| Already on premium or higher tier | Rework — model is not the bottleneck |

### Format for Escalation Recommendation

Include in the findings section when applicable:

```
| # | Severity | Finding | Suggested Fix |
|---|----------|---------|---------------|
| N | Medium   | {reasoning-dependent issue} | ⚡ Consider model escalation (current: economy → standard) before rework |
```

The `/run` orchestrator uses these recommendations to decide whether to escalate the model or trigger a rework loop. See `docs/model-catalog.md` for the full escalation ladder.

## Done When

- [ ] Reviewer reports include all 6 factors with individual scores
- [ ] Factors below 60 are flagged as attention items
- [ ] Weakest factor is highlighted in report header
- [ ] Rework iterations include score comparison with delta
- [ ] `/scrum` uses domain weights from spec frontmatter (if declared) for aggregation
- [ ] `/scrum` tracks score trajectory when multiple iterations are available
- [ ] Reviewers include model tier in report header when known
- [ ] Reviewers include escalation recommendations when score is 50–74% on a lower-tier model
