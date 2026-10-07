---
name: repro
description: "Shared reproduce-the-symptom procedure for bug/issue work. Used by both /fix (standalone debugging) and the repro-specialist pre-plan agent (ticket pre-plan wave, orchestrated /run). Finds repo-documented run/test commands, attempts a minimal reproduction, and reports evidence — never a fix."
---

# Repro — reproduce the symptom, safely

## When to use

- `/fix`, step **2. Reproduce** of its reproduce → isolate → fix → verify workflow.
- `repro-specialist` (pre-plan wave, bug/issue tickets) — same procedure, earlier in the pipeline,
  feeding `/prd` with empirical evidence instead of (or alongside) the domain specialists'
  reasoning-only hypotheses.

Both callers follow the **same** steps below so there is one implementation of "how do we safely
try to reproduce this," not two.

## Non-negotiable: never improvise a way to run the system

This procedure **only** uses commands the repository **already documents**. It never invents a
`docker run ...`, a server-start one-liner, or a port to bind — that is exactly the kind of ad-hoc
shell this framework's Zero-Trust philosophy exists to prevent (same reasoning as "no inline
`python3 -c`, no raw shell for mechanical work" elsewhere in this framework). If the repo doesn't
document a way to run or test the affected surface, **say so and stop** — do not get creative.

## Workflow

1. **Find a documented entry point**, in this order of preference:
   - An existing, already-passing test that exercises the affected area (unit/integration/e2e) —
     the cheapest and safest repro vehicle. Prefer this over anything that starts a service.
   - A test runner command declared in the repo (`package.json` scripts, a `Makefile` target, a
     `tox.ini`/`pytest.ini` profile, a CI job step you can run locally) — run the **narrowest**
     subset that covers the affected surface, not the full suite, unless that's the only option.
   - A documented local-run command (`docker-compose up`, a `Makefile` `run`/`dev` target, a
     README "Running locally" section) — only if a test-level repro isn't possible and the
     documented command is safe to run locally (no production targets, no destructive flags).
   - If **none** of the above exist for the affected surface: stop here. Report "no documented
     way to reproduce this locally" as a finding — that absence is itself useful signal (often
     points at a missing test/observability gap worth flagging to `testing-observability`
     grounding or `/spectech`).

2. **Write the smallest reproduction** that exercises the reported symptom:
   - If extending an existing test file, add **one** minimal case (or minimal fixture) that
     triggers the symptom — don't restructure the existing suite.
   - If no existing test fits, write one small, throwaway script/test **using the project's own
     test framework and conventions** (same assertion style, same fixtures/helpers already in
     use) — not a bespoke ad-hoc script in a different style.

3. **Run it** via the documented command found in step 1. Capture:
   - Exact command run.
   - Full error output / stack trace / assertion failure (verbatim, not paraphrased).
   - What was expected vs. what actually happened.

4. **Report evidence, never a fix:**
   - State the reproduction command, the captured failure, and what it rules in/out as root
     cause — but stop short of proposing the code change that would fix it. That's `/spectech`'s
     job (or `/fix`'s own later "Propose" step when called standalone).

5. **If reproduction fails to trigger the symptom** (the "repro" doesn't actually fail): say so
   explicitly — do not force a conclusion. Report what was tried and what didn't reproduce; that
   narrows the search even when it doesn't confirm a hypothesis.

## Cleanup

Remove any throwaway test/script you added for reproduction before finishing, **unless** the
caller explicitly wants it kept as a regression test (common for `/fix`'s later "Verify" step —
in that case, keep it and say so explicitly rather than silently leaving scratch files behind).

## Output contract

```markdown
## Repro

- **Command:** <exact command run>
- **Result:** reproduced | did not reproduce | no documented way to attempt this
- **Evidence:** <verbatim error/stack trace, or "n/a">
- **Expected vs. actual:** <one line>
- **Notes:** <e.g. "no test harness covers this area — observability gap">
```
