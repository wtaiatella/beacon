---
description: "DEPRECATED as default onboarding: prefer ARC MCP (AvaTax Release Central) for curated, indexed context—see docs/reference/arc-mcp-workflow.md. Use when a repo is not onboarded to ARC and only as a fallback: builds knowledge/{project}/ from deep codebase analysis. Expensive; run manually, not in the regular pipeline."
argument-hint: "<target-dirs>"
---
Use the **kb** subagent (Task tool, `subagent_type: kb`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
