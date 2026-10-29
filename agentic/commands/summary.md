---
description: "Use when producing post-pipeline handoff documentation or invoking /summary after QA. Generates comprehensive 'what was done' documentation after pipeline completion. Under orchestrated /run, expects artifacts/qa-report.md (when persisted) plus gate scores and minimal delegation context—not full diffs, artifacts/scanners/ raw files, or MCP briefs in the prompt; may run git-diff-summary.sh and scoped reads in-session—see run-pipeline § 8. Output is designed for future Jira/Confluence integration via /sync."
argument-hint: "<spec-or-folder>"
---
Use the **summary** subagent (Task tool, `subagent_type: summary`) to handle this request. Pass the following arguments to it verbatim, persist the returned Markdown to `<ticket-folder>/summary.md` if the subagent returned it as text instead of writing the file directly, and relay the final result back to me:

$ARGUMENTS
