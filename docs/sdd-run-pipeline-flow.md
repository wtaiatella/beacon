# SDD `/run` pipeline — Excalidraw flowchart

**File:** [`sdd-run-pipeline-flow.excalidraw`](./sdd-run-pipeline-flow.excalidraw)

## How to open

1. **Excalidraw web:** [excalidraw.com](https://excalidraw.com) → menu → **Open** → select the `.excalidraw` file  
2. **VS Code / Cursor:** install an Excalidraw extension and open the file  
3. Drag-and-drop the file onto excalidraw.com

## Layout

| Column | Content |
|--------|---------|
| **Left** | Happy path (process boxes) |
| **Middle-right** | Decisions / gates (diamonds) |
| **Far right** | Notes (pre-plan, ticket folder, phase rules, git) |

This avoids the “everything stacked on the center axis” problem of the earlier draw.io version.

## What it covers (simplified)

1. `/run` → §1 branch consent → §2 Init  
2. Optional pre-plan MCP  
3. `prd` → `spectech` → `tasks` → plan-reviewer + scrum  
4. Per phase: §5 implement → §6 review/scrum (loop if more phases / REWORK)  
5. §7.0 scanners → QA → §7.1 scrum → summary → §9 Finish → complete  

Normative detail remains in [`.agents/skills/run-pipeline/SKILL.md`](../.agents/skills/run-pipeline/SKILL.md) and [`run-pipeline-reference.md`](./run-pipeline-reference.md).

## Edit tips

- Drag columns independently; keep main flow left, diamonds right.  
- Dashed arrows = REWORK / next-phase loops.  
- Dotted lines = notes only (not control flow).
