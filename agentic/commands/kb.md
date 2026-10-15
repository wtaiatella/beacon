---
description: "Optional, persistent cross-ticket knowledge base — builds knowledge/{project}/ from deep codebase analysis. Complements (does not replace) the per-ticket pre-plan domain specialists (system-design-specialist, etc.), which ground every ticket in the current code regardless of whether /kb has been run. Expensive; run manually, not in the regular pipeline."
argument-hint: "<target-dirs>"
---
Use the **kb** subagent (Task tool, `subagent_type: kb`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
