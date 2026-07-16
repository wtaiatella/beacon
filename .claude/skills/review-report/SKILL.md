---
name: review-report
description: "Structured code review report template for the /qa persona. Compiles findings from spec-validator, security-scanner, and QA's own analysis into a unified report."
---

# Review Report

## When to Use

- When `/qa` produces a unified review report (standalone or via `/run` QA gate)
- When compiling findings from `spec-validator`, `security-scanner`, and QA's own analysis
- Any structured review that needs severity-ranked findings with a clear verdict

Combine automated outputs with human judgment; **do not** omit sections -- use "N/A" or "None" when empty.

## Inputs to gather

1. **git-diff-summary.sh** (or equivalent): changed files, line stats, repos touched.
2. **spec-validator** output: task matrix vs spec, acceptance criteria coverage.
3. **security-scanner** output: findings with locations.
4. Your own pass: tests, integration, domain-specific checks.

## Report structure (required order)

### 1. Changes Summary

- Repositories touched.
- Files modified (high level; group by area if long).
- Lines added / removed (from git-diff-summary or `git diff --stat`).
- Optional: link to MR or branch if provided.

### 2. Spec Compliance

- Paste or summarize **spec-validator** output:
  - Task completion matrix (which tagged tasks verified done vs pending).
  - Acceptance criteria: met / partial / not met (with evidence or gap).
- **Bidirectional coverage map** (both directions matter):
  - **Requirement → code:** each PRD AC / user story / spectech component maps to observable implementation + test. A requirement with **zero evidence** is a coverage gap (Critical/High).
  - **Code → requirement:** each material change maps back to a requirement. Changes that map to **nothing** are **scope creep / unrequested work** — flag them.
- **Classify each gap by type** alongside severity: `missing` (nothing there) · `partial` (incomplete) · `contradicts` (does the wrong thing) · `unrequested` (out of scope).

### 3. Security Findings

- Paste or summarize **security-scanner** output.
- Each issue: **severity**, **title**, **file:line** (or path), short description, suggested fix.
- If clean: state explicitly: "No security-scanner findings."

### 4. Test Coverage Assessment

- Were **new or updated tests** added for this change?
- Edge cases: error paths, boundary values, authz/authn if relevant.
- Obvious gaps (untested critical paths, missing integration test when required by spec).

### 5. Code Quality Findings

- Correctness risks, error handling, logging appropriateness.
- Leftover debug code, dead code, TODOs that should block merge.
- Naming, structure, complexity (call out only material issues).
- Cross-domain integration (API contracts, event schemas, config drift).

### 6. Domain-Specific Checks

Apply the rows that match changed domains:

| Domain | Focus |
|--------|--------|
| **[dev]** | Correctness, error handling, test quality, maintainability |
| **[sre]** | Secrets handling, IAM least-privilege, idempotency, resource limits, rollback path |
| **[data]** | Schema compatibility, PII handling, migration reversibility (up/down), query cost |

List concrete bullets per domain; use "N/A" for untouched domains.

### 7. Verdict

Choose one:

| Verdict | When to use |
|---------|-------------|
| **Approved** | No open **Critical** or **High** findings; acceptance criteria met per spec-validator; security acceptable for merge target. |
| **Changes Requested** | Any **Critical** or **High** finding remains; or acceptance criteria not met; or security blockers. |

**Approval rules (normative):**

- Any **Critical** finding -> **Changes Requested**.
- Any **High** finding -> **Changes Requested**.
- **Medium** / **Low** only -> may **Approve** with suggestions listed in the report body.
- **Security findings are Critical-by-default**; the block is **enforced** (no bypassable "proceed anyway" — a waiver requires explicit, documented process approval).
- **Calibrate — not everything is Critical.** Reserve Critical/High for real blockers; don't push nitpicks up the scale to force a block.

### 8. Next Steps (rejection only)

Include this section **only** when verdict is **Changes Requested**.

For each unresolved finding (or group):

- Map to **persona** and **repo/path**: e.g. "Re-run **/dev** on `myapp/` to fix items 1-3 (correctness + tests)."
- **Fix order:** blocking (breaks / security) first → simple fixes → complex fixes; test each fix individually and check for regressions.
- On re-submission, the re-review re-verifies **these specific findings** (plus regressions) — it does not re-open closed items or rubber-stamp.

---

## Severity definitions

| Level | Meaning |
|-------|---------|
| **Critical** | Must fix before merge: security vulnerability, data loss/corruption risk, or equivalent production safety issue. |
| **High** | Must fix: correctness bug, violated requirement, missing mandatory behavior per spec. |
| **Medium** | Should fix: maintainability, partial gap, reliability under edge cases. |
| **Low** | Suggestion: style, minor polish, non-blocking improvements. |

## Formatting tips

- Use stable **IDs** for findings (1, 2, 3...) so "Next Steps" can reference them.
- **Every finding carries two references:** the **evidence** (`file:line`, or migration/table name for data) **and** the **source-ref** it traces to (`FR-###` / `SC-###` / `AC.N` / task `T###` / spectech section). Findings that trace to no requirement are the scope-creep signal.
- Keep scanner excerpts **summarized** if verbose; full logs can be appendix or CI link.
- Prefer verifying against the **actual diff/code and fresh command output** — not the implementer's summary.

## Done when

- [ ] All eight sections addressed (section 8 only if Changes Requested).
- [ ] Verdict matches approval rules.
- [ ] Severities applied consistently with definitions above.
