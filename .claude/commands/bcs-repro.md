---
description: "Local, evidence-based before/after reproduction of a ticket's reported defect: delegates infra to /bcs-sandbox, auto-detects initial-state vs. fix-verification mode from the ticket folder's own state, saved as repro.md. Runs right after /bcs-ticket-intake, before /prd. Optional; standalone — not wired into /run."
argument-hint: "<ticket-folder | JIRA-KEY> [--before|--after]"
---
Use the **bcs-repro** subagent (Task tool, `subagent_type: bcs-repro`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
