---
description: "Validates that code implementation matches its architecture spec. Compares code changes against the spec's domain-tagged task list and acceptance criteria. Orchestrated /run: main session persists bounded output under docs/sessions/<id>/artifacts/scanners/ (canonical spec-validator filename); Task(qa) consumes paths/summaries per LPP—not nested Task from qa. Output is bounded Markdown (section/table caps, top gaps first) for orchestrator injection into Task(qa). Use when reviewing code for spec compliance."
argument-hint: "<spec>"
---
Use the **spec-validator** subagent (Task tool, `subagent_type: spec-validator`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
