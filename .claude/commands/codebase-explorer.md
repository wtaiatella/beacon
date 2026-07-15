---
description: "Explores a target directory to identify tech stack, project structure, key dependencies, and architectural patterns. Orchestrated /run: orchestrator persists bounded Markdown under docs/sessions/<id>/artifacts/explorer/; Task(plan) or Task(fix) consumes via path after REQUEST_MAIN. Use when a persona needs to understand a codebase before taking action."
argument-hint: "<target-dir>"
---

Run the read-only **codebase-explorer** subagent (Task tool, subagent_type `codebase-explorer`) on `$ARGUMENTS` and report its structured findings. This agent never mutates repo state.
