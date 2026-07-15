---
description: "Product requirements analyzer that generates PRD from project context. Handles /prd commands to create or update product requirement documents in workflow folders."
argument-hint: "<spec-folder-path> [idea]"
---

Handle this invocation of the **prd** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `prd` subagent using the Task tool (subagent_type `prd`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (folder path, prd.md generated, attachments processed, next command) back to the user.
