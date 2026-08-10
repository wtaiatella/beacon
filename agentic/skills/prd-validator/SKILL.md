---
name: prd-validator
description: "Unified validator for PRD.md that detects implicit requirements gaps and validates scope discipline. Combines implicit-requirements-hunter + scope-validation."
---

# PRD Validator

## When to Use

- After generating prd.md with `/prd`
- Before approving PRD for technical design phase
- To catch missing requirements and scope creep early

Output: Validation report with issues or approval-to-proceed

## Validation Strategy

This skill performs **three parallel validations** on the generated PRD:

### 1. Implicit Requirements Hunter

Scans PRD for common gaps that were forgotten:

**Error Handling Gaps:**
- How do errors surface to users?
- What happens if external services (Stripe, email, etc) are down?
- Timeout handling?
- Rate limiting?
- Retry strategy?

**Concurrency & Consistency:**
- Race conditions? (e.g., two users starting same trial)
- Data consistency checks?
- Duplicate prevention?
- Transaction boundaries clear?

**Observability & Monitoring:**
- Key metrics to track?
- Logging strategy?
- Alerting thresholds?
- Debug-ability in production?

**Security & Privacy:**
- OWASP Top 10 coverage?
- Data encryption (at rest, in transit)?
- Authentication/Authorization strategy?
- Rate limiting against abuse?
- PII handling / GDPR compliance?

**Performance & Scalability:**
- Expected load/volume?
- SLO / latency targets?
- Caching strategy?
- Database query efficiency?
- Horizontal scalability needs?

**Reliability & Resilience:**
- Failure modes covered?
- Graceful degradation?
- Recovery procedures?
- Circuit breakers?
- Fallback behaviors?

### 2. Scope Validation

Checks that PRD respects scope boundaries:

**In-Scope Discipline:**
- Are all items justified?
- Do items clearly belong to THIS feature?
- No gold-plating?

**Out-of-Scope Clarity:**
- Is each exclusion documented with reason?
- Are future phases clear (Phase 2, Phase 3)?
- No ambiguous boundaries?

**Acceptance Criteria Completeness:**
- Each story has testable AC?
- No vague language ("user can easily", "system should handle")?
- Can QA write test cases from these?

**Priority Consistency:**
- P0/P1/P2 clearly marked?
- Do priorities match business value?
- No hidden dependencies?

### 3. Requirement Structure & Testability

Checks that the PRD's structure is built for downstream testability and hand-off:

**User Stories:**
- Are stories prioritized (P1/P2/P3)?
- Does each story have a **"Why this priority"** and an **"Independent Test"**?
- Is each story an independently testable MVP slice (implementing one alone delivers value)?

**Acceptance Criteria:**
- Are ACs in **Given/When/Then** form (each reads as a test case)?
- Any AC still phrased as a vague assertion instead of a scenario?

**Success Criteria:**
- Present and **measurable** (metric: time, %, count, rate)?
- **Technology-agnostic** — no framework/language/DB names, no internal-latency figures
  (e.g., "API < 200ms", "Redis hit rate")? Those belong in spectech.md, not the PRD.
- Stated from the user/business perspective?

**Clarification Markers:**
- Any unresolved `[NEEDS CLARIFICATION: …]` markers remaining? (Must be **zero** at hand-off.)
- Were no more than **3** used, and each resolved into Assumptions or an answered decision?

## Validation Output

### Case 1: Issues Found

```markdown
## PRD Validation Report: ❌ ISSUES FOUND

### Implicit Requirements Gaps (5 issues)

**Critical:**
- [ ] Error Handling: No documented behavior when Stripe API fails
- [ ] Security: No mention of rate limiting (vulnerability to brute force)

**Important:**
- [ ] Performance: No SLO targets defined (how fast should signup complete?)
- [ ] Observability: No logging strategy for payment events
- [ ] Concurrency: No handling of duplicate trial signups

### Scope Validation Issues (2 issues)

**Scope Creep:**
- [ ] "Support multiple payment methods" is mentioned but not in scope (Phase 2?)
- [ ] Notification "customization" seems like Phase 2, clarify

**Clarity:**
- [ ] AC.3 says "notification sent" but doesn't specify: email only or SMS too?

### Summary

**Status:** ❌ BLOCKED  
**Total Issues:** 7 (2 critical, 3 important, 2 clarity)  
**Recommendation:** Fix critical + important issues before proceeding to design phase

### Next Steps
1. Address critical issues (error handling, security)
2. Define performance SLOs
3. Clarify phase boundaries
4. Re-run validation
```

### Case 2: Approved

```markdown
## PRD Validation Report: ✅ APPROVED

**Implicit Requirements:** All categories covered
- ✅ Error handling: Documented Stripe failure behavior, timeouts, retries
- ✅ Concurrency: Database unique constraint prevents duplicate trials
- ✅ Observability: Logging strategy defined, key metrics identified
- ✅ Security: Rate limiting documented, GDPR compliance covered
- ✅ Performance: SLOs defined (signup < 200ms, notification < 24h)
- ✅ Reliability: Graceful degradation for email service failures

**Scope Validation:** Clean boundaries
- ✅ In-scope items justified and clear
- ✅ Out-of-scope items explicitly Phase 2
- ✅ All ACs are testable
- ✅ Priorities align with business value

### Summary

**Status:** ✅ APPROVED  
**Quality Score:** 95%  
**Ready for:** Technical design phase (/spectech)

### Recommendation
PRD is well-structured, requirements are clear, no blockers identified. Ready to proceed to architecture design.
```

## Validation Checklist

The validator checks:

- [ ] All error handling modes documented
- [ ] Concurrency scenarios identified
- [ ] Observability/logging strategy present
- [ ] Security concerns addressed (OWASP, encryption, auth)
- [ ] Performance SLOs or targets defined
- [ ] Reliability/resilience patterns clear
- [ ] In-scope items clearly justified
- [ ] Out-of-scope items documented with reason
- [ ] Phase boundaries explicit (Phase 1 vs Phase 2 vs Phase 3)
- [ ] User stories prioritized (P1/P2/P3), each with an Independent Test
- [ ] All acceptance criteria use Given/When/Then and are testable (no vague language)
- [ ] Success criteria are measurable AND technology-agnostic
- [ ] No unresolved `[NEEDS CLARIFICATION]` markers (≤3 used, all resolved)
- [ ] Priority labels consistent with business value
- [ ] No contradictions between sections

## Quality Score Calculation

```
Base Score: 100

For each category (Error Handling, Concurrency, Observability, Security, Performance, Reliability):
- Fully documented: 0 points deducted
- Partially covered: -5 points per category
- Not mentioned: -15 points per category

For scope validation:
- Clear boundaries: 0 points deducted
- Ambiguous items: -3 points per item
- Scope creep detected: -10 points

For requirement structure & testability:
- Unresolved [NEEDS CLARIFICATION] marker: -15 points each (also forces BLOCKED)
- Success criteria missing, non-measurable, or leaking implementation: -10 points
- User stories not prioritized / missing Independent Test: -5 points
- Acceptance criteria not in Given/When/Then form: -3 points per criterion

Final Score = Max(0, Base Score - Deductions)

Status:
- ≥ 90: ✅ APPROVED
- 75-89: ⚠️ APPROVED WITH NOTES (fix minor gaps)
- 50-74: ❌ NEEDS WORK (address important issues)
- < 50: ❌ BLOCKED (critical issues)
```

## Integration with /prd

When `/prd` finishes generating prd.md:

1. Run this validator
2. If issues found: present report, suggest fixes
3. If approved: update `_state.json` (see `bcs-ticket-workflow` skill, the only control-file
   convention) → validation outcome recorded alongside `steps.prd: "done"`
4. User can fix and re-run `/prd` (will re-validate)
5. Only approved PRDs proceed to `/spectech`

## Notes

- **Not prescriptive** — doesn't say "use Redis for caching", only checks if strategy is defined
- **Risk-focused** — highlights what could go wrong if not addressed
- **Testable** — all gaps should have corresponding test cases
- **Phase-aware** — distinguishes Phase 1 (required) vs Phase 2+ (future)
