---
description: "Task breakdown specialist that generates granular task lists. Reads spectech.md and produces tasks.md with task breakdown, phases, and estimations."
argument-hint: "<spec-folder-path>"
---

Handle this invocation of the **tasks** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `tasks` subagent using the Task tool (subagent_type `tasks`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: ask the user or escalate as needed — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (folder path, tasks.md generated, validation results, ready for implementation) back to the user.
