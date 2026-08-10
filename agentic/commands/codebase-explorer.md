---
description: "Explores a target directory to identify tech stack, project structure, key dependencies, and architectural patterns. Orchestrated /run: orchestrator persists bounded Markdown under docs/sessions/<id>/artifacts/explorer/; Task(plan) or Task(fix) consumes via path after REQUEST_MAIN. Use when a persona needs to understand a codebase before taking action."
argument-hint: "<target-dir>"
---
Use the **codebase-explorer** subagent (Task tool, `subagent_type: codebase-explorer`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
