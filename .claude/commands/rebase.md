---
description: "Multi-repo git-sync: checkout main/default, pull, checkout back, rebase (with backup branch) — for one, several, or every child repo. No MR creation, no Jira transition. Standalone — not wired into /run."
argument-hint: "[repo ...]"
---
Use the **rebase** subagent (Task tool, `subagent_type: rebase`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
