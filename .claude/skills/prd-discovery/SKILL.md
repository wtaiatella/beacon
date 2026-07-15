---
name: prd-discovery
description: "Discovery / brainstorm phase for the /prd persona (Phase A). Refines a vague project idea into a clear brief BEFORE drafting prd.md, through bounded one-question-at-a-time dialogue across requirement areas. Skippable when the input is already rich. Requirements refinement only (WHAT) — never solution architecture (HOW)."
---

# PRD Discovery (Phase A Brainstorm)

Turn a vague idea into a clear, shaped brief **before** writing `prd.md`. Adapted from the
superpowers `brainstorming` skill, scoped to our SDD: this refines **requirements (WHAT)**, not
solution design (HOW — that belongs to `/plan` and `/spectech`).

## When to Use

- `/prd` received a thin or ambiguous idea and drafting now would mean guessing on high-impact
  decisions (scope, users, success).
- The problem space, target users, or definition of success are unclear.

## When to SKIP (important)

**Momentum over interrogation.** Skip this phase entirely — go straight to drafting — when the
input already answers the areas below. Skip if **any** of these hold:

- A detailed idea/brief or client PRD was provided.
- `attachments/` already contain requirements docs, wireframes, or a spec that covers the areas.
- The request is a small, well-understood change with obvious scope.

Never re-ask what you already have. If only one or two areas are unclear, don't run a full
discovery — just ask those (or default them and record in Assumptions).

## The Discovery Protocol

Mirror the interactive style, bounded for a requirements phase:

1. **Assess first, ask second.** Read the idea + attachments + `_state.json`/`_notes.md` (see the
   `ticket-workflow` skill — the only control-file convention). Build an internal
   coverage map of the areas below: Clear / Partial / Missing. Only Partial/Missing **and
   high-impact** areas earn a question.
2. **One question at a time.** Never present a wall of questions. Use `AskUserQuestion` (or a
   `QUESTION:` / `ASK_USER` escalation under the orchestrator).
3. **Prefer multiple choice.** Lead with a **recommended option and a 1–2 sentence rationale**
   (best practice / most common / lowest risk). Always allow a custom short answer.
4. **Budget ~5–7 questions total.** Cover the highest-impact unresolved areas first. Stop early
   when critical ambiguity is resolved or the user signals "done" / "good" / "proceed".
5. **Default the rest.** For low-impact gaps, choose an industry-standard default instead of
   asking — and record it in the PRD's **Assumptions**.
6. **Reveal nothing ahead.** Don't preview the queued questions.

## Question Areas (requirements-level only)

Probe only the underspecified ones. Order roughly by impact (scope/users/success first):

- **Problem & motivation** — What problem does this solve? Why now? What happens if we do nothing?
- **Target users / personas** — Who uses this? Any distinct roles with different needs/permissions?
- **Desired outcome / success** — What does "done and working" look like from the user's side?
  (feeds measurable, technology-agnostic Success Criteria)
- **Scope boundaries** — What is explicitly *in*, and what is *out* / a later phase?
- **Priorities / MVP** — If only one slice ships first, which delivers value? (feeds P1/P2/P3)
- **Key scenarios & edge cases** — Primary happy path; notable error/empty/boundary situations.
- **Data & entities (business level)** — What core things are created/tracked? Any uniqueness or
  retention expectations? (no schema/DB design)
- **External dependencies** — Which external services/systems are expected to be involved?
- **Business constraints** — Deadline, compliance/regulatory, budget, must-use / must-avoid at the
  business level (not a technology-selection exercise).

## WHAT-not-HOW Guardrail

- Do **not** explore solution approaches, architectures, frameworks, or data models here — that is
  the `/plan` architect's job (the superpowers "propose 2–3 approaches" step lives there, not in
  the PRD).
- If a HOW question surfaces (e.g., "REST vs GraphQL?"), do **not** decide it. Note it as a hand-off
  hint for `/spectech` / `/plan` and move on.

## Output: Refined Idea Brief

End with a short brief (a handful of bullets, not a document) that seeds `generate-prd`:

```
### Refined Idea Brief
- Problem: <one line>
- Users: <who>
- Success looks like: <measurable outcome(s)>
- In scope: <bullets>   |   Out / later: <bullets>
- MVP slice (P1): <the smallest valuable story>
- Key scenarios: <happy path + notable edge cases>
- Dependencies: <external systems>
- Assumed defaults (unasked): <defaults chosen → go to Assumptions>
- Deferred to /spectech or /plan (HOW): <any parked technical questions>
```

- Resolved answers flow into the matching `prd.md` sections during drafting.
- **Still-unresolved critical** items become inline `[NEEDS CLARIFICATION]` markers (budget 3) for
  the `/prd` clarification loop.
- **Non-blocking** leftovers go to the PRD's **Deferred Questions** section.

## Guardrails

- **Skippable by design** — a rich input means no discovery. Do not manufacture questions.
- **Bounded** — hard cap ~5–7 questions; recommendation-first; custom answers always allowed.
- **Requirements only** — refine WHAT; never lock HOW.
- **No stalling** — default low-impact gaps and keep moving; only high-impact ambiguity blocks.
- **Respect early exit** — "proceed" ends discovery immediately; default whatever remains.
