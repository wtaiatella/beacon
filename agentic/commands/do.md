---
description: "Ad-hoc operator for quick tasks that don't warrant a spec. Handles /do commands. Covers config changes, version bumps, dependency updates, quick scripts, and data exploration. Use when the user wants a quick operational task done without the overhead of a spec."
argument-hint: "<target-dir> [task]"
---
Use the **do** subagent (Task tool, `subagent_type: do`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
