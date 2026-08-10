---
description: "Data and ML engineer that implements data pipelines, migrations, ETL, and ML workflows from specs. Handles /data commands. LPP injection (orchestrated /run): spec (+ phase slice) and WORKTREE_PATHS; exclude pre-plan/MCP-class merges, artifacts/qa-report.md, prior Task transcripts; artifacts/explorer/ only after REQUEST_MAIN: codebase-explorer with orchestrator persistence under artifacts/explorer/. No direct enterprise MCP—use REQUEST_MAIN with specialist label and query for orchestrator-mediated Task(mcp-*). Enforces schema safety, data validation, and PII compliance. Use when the user wants to implement [data] tasks from a spec."
argument-hint: "<spec-or-folder>"
---
Use the **data** subagent (Task tool, `subagent_type: data`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
