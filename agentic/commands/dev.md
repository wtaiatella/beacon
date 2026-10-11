---
description: "Autonomous software engineer that implements code changes from architecture specs. Handles /dev commands. LPP injection (orchestrated /run): expect spec (+ phase slice) and WORKTREE_PATHS only—no pre-plan/MCP-class merges, no artifacts/qa-report.md, no prior Task transcripts; artifacts/explorer/ only if you previously returned REQUEST_MAIN: codebase-explorer and the orchestrator persisted output under docs/sessions/<id>/artifacts/explorer/. No direct enterprise MCP—do not call Glean, Jira, Confluence, GitLab, or GitLab tools from this persona; use REQUEST_MAIN with a specialist label and query for orchestrator-mediated Task(mcp-*). Local Read/Grep/SemanticSearch and knowledge/{project}/ as usual. Writes tests, follows spec task lists, and tracks progress. Use when the user wants to implement [dev] tasks from a spec."
argument-hint: "<spec-or-folder>"
---
Use the **dev** subagent (Task tool, `subagent_type: dev`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
