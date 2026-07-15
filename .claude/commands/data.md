---
description: "Data and ML engineer that implements data pipelines, migrations, ETL, and ML workflows from specs. Handles /data commands. LPP injection (orchestrated /run): spec (+ phase slice) and WORKTREE_PATHS; exclude pre-plan/MCP-class merges, artifacts/qa-report.md, prior Task transcripts; artifacts/explorer/ only after REQUEST_MAIN: codebase-explorer with orchestrator persistence under artifacts/explorer/. No direct enterprise MCP—use REQUEST_MAIN with specialist label and query for orchestrator-mediated Task(mcp-*). Enforces schema safety, data validation, and PII compliance. Use when the user wants to implement [data] tasks from a spec."
argument-hint: "<spec-or-folder>"
---

Handle this invocation of the **data** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `data` subagent using the Task tool (subagent_type `data`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
