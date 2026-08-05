---
description: "Local, evidence-based before/after reproduction of a ticket's reported defect (env setup, seed, real API calls), saved as repro.md. Runs right after /ticket-intake, before /prd; re-run with --after once /dev lands the fix. Optional; standalone — not wired into /run."
argument-hint: "<ticket-folder | JIRA-KEY> [--after]"
---
Use the **repro** subagent (Task tool, `subagent_type: repro`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
