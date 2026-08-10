---
name: kb-concentrator
description: "Knowledge concentrator — updates knowledge/global-kb/ with the system-level, cross-repo view (end-to-end flows, integration boundaries, where responsibilities live), aggregating the per-repo KBs. Incremental and evidence-driven. Use after kb-refresh when changes affect the system-level picture. Standalone — not wired into the required /run orchestrator (FR-10, FR-15)."
---

# KB Concentrator

Maintains the **concentrator** at `knowledge/global-kb/` — the system-level view that sits above
the per-repo KBs, to support more accurate task/code analysis when projects call into each other
(FR-15). This is **new** tooling (DQ-1) — the existing `/kb` agent builds one project's KB, not a
cross-project view.

**Standalone (FR-10, D9):** not a step of the required orchestrator's sequence — like `kb-refresh`,
it operates on `knowledge/` across the whole workspace, not one ticket folder, so it is exempt from
the `_state.json`/`_notes.md` per-ticket contract (spectech D9). Typically chained after
`kb-refresh`, but independently invocable.

## Trigger & Input

- **Trigger:** `/kb-concentrator [flow-or-topic hint]` — arrives as `$ARGUMENTS`.
- **Optional:** hint about which cross-repo flow or topic to focus on. Empty = general incremental
  pass.
- Read the current `knowledge/global-kb/` (bootstrap per Required behavior if absent) and the
  relevant per-repo `knowledge/<repo>/` KBs, apply an incremental update, then report what was
  added/updated.

## Goal

Produce an **incremental, evidence-driven** update of the concentrator, preserving:

1. **End-to-end runtime flows** across repos (e.g. UI → API/engine → workers → persistence →
   render), as ordered sequences.
2. **Integration boundaries** — who calls whom, contracts/schemas at the seams (link to each
   `knowledge/<repo>/interfaces.md`).
3. **Where responsibilities live** — hardcoded vs config-driven vs runtime/user-context, with the
   code paths that establish each.
4. **Fallback / error behavior** across layers.

## Required behavior

1. Use the workspace as the source of truth: all child repos + everything under `knowledge/`
   (per-repo KBs + `global-kb/`).
2. Prefer **incremental edits** — do not rewrite unrelated sections.
3. Keep every assertion tied to a concrete code path (`repo/file:line`).
4. Keep the language practical for onboarding humans **and** agents.
5. If `knowledge/global-kb/` does not exist, **bootstrap** it: an `_index.md` (always-loaded
   overview) plus topic files for each major end-to-end flow.

## Suggested layout

```
knowledge/global-kb/
├── _index.md                 # system overview, repo map, entry points (always loaded)
├── <flow-name>-end-to-end.md # one per major cross-repo flow
└── integration-map.md        # seams/contracts between repos
```

## Guardrails

- Incremental over rewrite; evidence over assertion.
- The concentrator summarizes and links — it does not duplicate full per-repo KB content.
- Standalone: not invoked automatically by the required orchestrator (FR-10).
