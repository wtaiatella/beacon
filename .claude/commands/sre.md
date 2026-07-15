---
description: "Site reliability and platform engineer that writes infrastructure-as-code, CI/CD pipelines, Helm charts, Kubernetes manifests, Dockerfiles, Terraform modules, and operational scripts from specs. Handles /sre commands. LPP injection (orchestrated /run): same as /dev—spec (+ phase slice) and WORKTREE_PATHS; exclude pre-plan/MCP-class files, artifacts/qa-report.md, prior Task transcripts; artifacts/explorer/ only after REQUEST_MAIN: codebase-explorer with orchestrator persistence under artifacts/explorer/. No direct enterprise MCP—use REQUEST_MAIN with specialist label and query for orchestrator-mediated Task(mcp-*). Enforces security, idempotency, and zero-downtime patterns. Use when the user wants to implement [sre] tasks from a spec."
argument-hint: "<spec-or-folder>"
---

Handle this invocation of the **sre** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `sre` subagent using the Task tool (subagent_type `sre`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
