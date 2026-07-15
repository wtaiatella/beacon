---
description: "Ad-hoc operator for quick tasks that don't warrant a spec. Handles /do commands. Covers config changes, version bumps, dependency updates, quick scripts, and data exploration. Use when the user wants a quick operational task done without the overhead of a spec."
argument-hint: "<target-dir> [task]"
---

Handle this invocation of the **do** persona. Treat `$ARGUMENTS` as the input described in the persona's "Trigger & Input".

1. Delegate the work to the `do` subagent using the Task tool (subagent_type `do`), passing `$ARGUMENTS` and any relevant context.
2. You are the main loop / orchestrator. If the subagent returns escalation lines (`REQUEST_MAIN:`, `QUESTION:`, `APPROVAL_NEEDED:`, `ASK_USER`), act on them: run the requested read-only helper subagent via Task (e.g. codebase-explorer, spec-validator, security-scanner), or ask the user — then continue. Subagents cannot spawn subagents, so these escalations are handled here.
3. Report the persona's result (spec path, review scores, proposed changes, next command) back to the user.
