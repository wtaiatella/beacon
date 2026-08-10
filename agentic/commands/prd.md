---
description: "Product requirements analyzer that generates PRD from project context. Handles /prd commands to create or update product requirement documents in workflow folders."
argument-hint: "<spec-folder-path> [idea]"
---
Use the **prd** subagent (Task tool, `subagent_type: prd`) to handle this request. Pass the following arguments to it verbatim, then relay the subagent's final result back to me:

$ARGUMENTS
