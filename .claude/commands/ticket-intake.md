---
description: "Ticket intake — project-agnostic: fetch Jira issue + comments, create the ticket working folder, save ticket.md, download attachments (incl. .drawio), write a plain-language impact-analysis.md (complexity/repos/blockers), init _state.json/_notes.md. Standalone — not wired into /run."
argument-hint: "<JIRA-KEY | jira-url>"
---
Use the **ticket-intake** subagent (Task tool, `subagent_type: ticket-intake`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
