---
description: "Local before/after ticket reproduction: classifies input/data kind, reuses or creates durable in-repo fixtures, delegates infra to /bcs-sandbox, writes repro.md with a PRD/integration-test contract. After /bcs-ticket-intake, before /prd. Optional; standalone — not wired into /run."
argument-hint: "<ticket-folder | JIRA-KEY> [--before|--after]"
---
Use the **bcs-repro** subagent (Task tool, `subagent_type: bcs-repro`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me.

Tell the subagent to follow `.claude/skills/bcs-repro/SKILL.md` for fixture placement: increment the existing container (append to canonical `_database/*.cjson`, or add a sibling under `v3-goods` / `v3-services` / `v2-*`). Ticket-named `_input/bg-XXXX/` folders are last resort. Never invent `mugil/test/fixtures/<TICKET>/`.

$ARGUMENTS
