---
description: "Use when producing post-pipeline handoff documentation or invoking /summary after QA. Generates comprehensive 'what was done' documentation after pipeline completion. Under orchestrated /run, expects artifacts/qa-report.md (when persisted) plus gate scores and minimal delegation context—not full diffs, artifacts/scanners/ raw files, or MCP briefs in the prompt; may run git-diff-summary.sh and scoped reads in-session—see run-pipeline § 8. Output is designed for future Jira/Confluence integration via /sync."
argument-hint: "<spec-or-folder>"
---

Handle this invocation of the **summary** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `summary` subagent using the Task tool (subagent_type `summary`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
