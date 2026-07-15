---
description: "Scoped flowchart-vs-code conformance: when a ticket ships a marked .drawio/diagram, verify the code matches it (flowchart is source of truth); on deviation, pinpoint the node and halt. Standalone — not wired into /run."
argument-hint: "<ticket-folder | JIRA-KEY>"
---
Use the **flowchart-check** subagent (Task tool, `subagent_type: flowchart-check`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
