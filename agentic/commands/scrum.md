---
description: "Use when evaluating pipeline gates (plan, implementation per phase, post-QA), reviewer reports, or cross-spec coordination. Agile lead combining Product Owner, Scrum Master, and Project Manager roles. Evaluates reviewer reports with business judgment. Two distinct run-pipeline gates: per-phase § 6 implementation gate (before QA) — final gatekeeper for that phase; combines domain reviewer scores with bounded phase security report (phase-N-security.md); MUST REWORK on High or Critical. § 7.1 post-QA gate (after Task(qa)) — separate authority; uses qa-report and scores, not full scanner dumps. Manages single specs at gate points AND coordinates across multiple active specs."
argument-hint: "<spec-or-reviewer-report>"
---
Use the **scrum** subagent (Task tool, `subagent_type: scrum`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
