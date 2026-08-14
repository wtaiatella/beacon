---
description: "Local before/after ticket reproduction: classifies input/data kind, reuses or creates durable in-repo fixtures, delegates infra to /bcs-sandbox, writes repro.md with a PRD/integration-test contract. After /bcs-ticket-intake, before /prd. Optional; standalone — not wired into /run."
argument-hint: "<ticket-folder | JIRA-KEY> [--before|--after]"
---
Use the **bcs-repro** subagent (Task tool, `subagent_type: bcs-repro`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
