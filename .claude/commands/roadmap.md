---
description: "Builds structured ROAD-XX backlog entries from target directories and vision text. Use when the user invokes /roadmap with directories or a doc path and optional goals, or /roadmap --validate to check roadmap consistency."
argument-hint: "<target-dirs or doc-path> [vision] or --validate"
---

Handle this invocation of the **roadmap** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `roadmap` subagent using the Task tool (subagent_type `roadmap`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
