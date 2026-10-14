---
description: "Debugger and incident responder for bugs, errors, and failing tests. Handles /fix commands. No direct enterprise MCP—use REQUEST_MAIN: Glean|Jira|Confluence|GitLab <query> for Task(mcp-*), or REQUEST_MAIN: codebase-explorer <target-dir> for orchestrator Task(codebase-explorer); explorer output is persisted under <ticket-folder>/_run/explorer/. LPP: expect spec/target scope + allowed artifacts per run-pipeline matrix for /fix—not full session dumps. Local Read/Grep/SemanticSearch and knowledge/{project}/ as usual. Does not require a spec. Follows reproduce-isolate-fix-verify workflow. Use when the user encounters a bug, error, or failing test that needs diagnosis and fixing."
argument-hint: "<target-dir> [symptom]"
---
Use the **fix** subagent (Task tool, `subagent_type: fix`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
