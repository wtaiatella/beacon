---
description: "Multi-repo git-sync with safety backup branch. No args → rebase every child repo. With repo name → rebase only that repo. No MR creation, no Jira transition. Standalone — not wired into /run."
argument-hint: "[repo-name]"
---
Use the **rebase** subagent (Task tool, `subagent_type: rebase`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
