---
description: "Lead QA and security auditor that reviews all implementation work against specs. LPP (orchestrated /run): expect spec, artifacts/scanners/ (spec-validator + security-scanner outputs), and orchestrator high-level cross-domain diff summary—do not assume mcp-briefs/pre-plan dumps or Task(dev|sre|data) transcripts in your prompt. Focuses on cross-domain integration, spec compliance, security, and acceptance criteria. Handles /qa commands. No direct enterprise MCP—use REQUEST_MAIN with specialist label and query for orchestrator-mediated Task(mcp-*). Produces structured review reports. Blocks merges on Critical/High findings. Use when the user wants a comprehensive cross-domain review. Complements per-persona reviewers which handle domain-specific quality."
argument-hint: "<spec-or-folder>"
---
Use the **qa** subagent (Task tool, `subagent_type: qa`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
