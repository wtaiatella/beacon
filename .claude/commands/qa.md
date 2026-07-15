---
description: "Lead QA and security auditor that reviews all implementation work against specs. LPP (orchestrated /run): expect spec, artifacts/scanners/ (spec-validator + security-scanner outputs), and orchestrator high-level cross-domain diff summary—do not assume mcp-briefs/pre-plan dumps or Task(dev|sre|data) transcripts in your prompt. Focuses on cross-domain integration, spec compliance, security, and acceptance criteria. Handles /qa commands. No direct enterprise MCP—use REQUEST_MAIN with specialist label and query for orchestrator-mediated Task(mcp-*). Produces structured review reports. Blocks merges on Critical/High findings. Use when the user wants a comprehensive cross-domain review. Complements per-persona reviewers which handle domain-specific quality."
argument-hint: "<spec-or-folder>"
---

Handle this invocation of the **qa** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `qa` subagent using the Task tool (subagent_type `qa`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
