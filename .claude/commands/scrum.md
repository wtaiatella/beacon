---
description: "Use when evaluating pipeline gates (plan, implementation per phase, post-QA), reviewer reports, or cross-spec coordination. Agile lead combining Product Owner, Scrum Master, and Project Manager roles. Evaluates reviewer reports with business judgment. Two distinct run-pipeline gates: per-phase § 6 implementation gate (before QA) — final gatekeeper for that phase; combines domain reviewer scores with bounded phase security report (phase-N-security.md); MUST REWORK on High or Critical. § 7.1 post-QA gate (after Task(qa)) — separate authority; uses qa-report and scores, not full scanner dumps. Manages single specs at gate points AND coordinates across multiple active specs."
argument-hint: "<spec-or-reviewer-report>"
---

Handle this invocation of the **scrum** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `scrum` subagent using the Task tool (subagent_type `scrum`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
