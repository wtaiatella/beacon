---
description: "DEPRECATED as default onboarding: prefer ARC MCP (AvaTax Release Central) for curated, indexed context—see docs/reference/arc-mcp-workflow.md. Use when a repo is not onboarded to ARC and only as a fallback: builds knowledge/{project}/ from deep codebase analysis. Expensive; run manually, not in the regular pipeline."
argument-hint: "<target-dirs>"
---

Handle this invocation of the **kb** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `kb` subagent using the Task tool (subagent_type `kb`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
