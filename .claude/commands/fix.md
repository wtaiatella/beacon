---
description: "Debugger and incident responder for bugs, errors, and failing tests. Handles /fix commands. No direct enterprise MCP—use REQUEST_MAIN: Glean|Jira|Confluence|GitLab|ARC <query> for Task(mcp-*), or REQUEST_MAIN: codebase-explorer <target-dir> for orchestrator Task(codebase-explorer); explorer output is persisted under docs/sessions/<id>/artifacts/explorer/. LPP: expect spec/target scope + allowed artifacts per run-pipeline matrix for /fix—not full session dumps. Local Read/Grep/SemanticSearch and knowledge/{project}/ as usual. Does not require a spec. Follows reproduce-isolate-fix-verify workflow. Use when the user encounters a bug, error, or failing test that needs diagnosis and fixing."
argument-hint: "<target-dir> [symptom]"
---

Handle this invocation of the **fix** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `fix` subagent using the Task tool (subagent_type `fix`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
