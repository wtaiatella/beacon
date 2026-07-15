---
description: "Technical specification designer that generates detailed technical specs. Reads PRD and produces spectech.md with architecture, APIs, data models, and testing strategy."
argument-hint: "<spec-folder-path>"
---

Handle this invocation of the **spectech** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `spectech` subagent using the Task tool (subagent_type `spectech`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: ask the user or escalate as needed — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (folder path, spectech.md generated, validation results, next command) back to the user.
