---
description: "Update knowledge/global-kb/ with the system-level, cross-repo view (end-to-end flows, integration boundaries), aggregating per-repo KBs. Incremental. Typically follows kb-refresh. Standalone — not wired into /run."
argument-hint: "[flow-or-topic hint]"
---

Treat `$ARGUMENTS` as an optional hint about which cross-repo flow or topic to focus the update on (empty = general incremental pass).

## Workflow

1. **Read** `.claude/skills/kb-concentrator/SKILL.md` (use the Read tool) and follow it as authoritative — this is a thin utility command, not a persona subagent (mirrors `/clone`'s shape).
2. Read the current `knowledge/global-kb/` (bootstrap it per the skill if absent) and the per-repo `knowledge/<repo>/` KBs relevant to `$ARGUMENTS` (or all, if no hint given).
3. Apply an incremental, evidence-driven update per the skill's Required behavior — do not rewrite unrelated sections.
4. Report a summary of what was added/updated in `knowledge/global-kb/`.

## Guardrails

- Incremental over rewrite; every assertion tied to a concrete code path.
- Does not duplicate full per-repo KB content — summarize and link.
