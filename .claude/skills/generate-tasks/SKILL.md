---
name: generate-tasks
description: "Task breakdown template and generation instructions for the /tasks persona. Produces tasks.md with a user-story-driven, stable-ID task list, phases, coverage map, and implementation strategy."
---

# Generate Tasks

## When to Use

- Breaking down technical specification into implementable tasks
- Creating task list from approved spectech.md
- Organizing work into phases and estimating effort
- Any time `/tasks` needs to produce or modify tasks.md file

Output format is **normative**: follow section order exactly.

## Prerequisites

- **Must read prd.md and spectech.md first** — validates that /prd and /spectech have completed
- If spectech.md missing, agent asks user to run `/spectech` first
- Cannot skip order enforcement

## Output Location and Naming

- **Directory:** `docs/specs/{slug}/` (same folder as prd.md and spectech.md)
- **Filename:** `tasks.md` (always this name)

## Task Line Format (normative)

Every task is a single checkbox line with this anatomy:

```
- [ ] T001 [US1][dev][P] Short imperative description (path/to/file.ts)
       │     │    │   │                                └─ file(s) created/modified — REQUIRED
       │     │    │   └─ [P] optional: parallelizable (different files, no incomplete deps)
       │     │    └─ domain tag: [dev] | [sre] | [data]  (multi-repo: [dev:repo])
       │     └─ user-story tag: [US1]/[US2]… — REQUIRED on story-phase tasks; OMIT on
       │                        Setup / Foundational / Polish tasks
       └─ stable ID: T001, T002… sequential in execution order (never renumber on edit)
```

Rules:
- **Stable IDs** `T001…` in execution order — used to reference tasks in chats, dependencies, and
  the coverage map. Once assigned, don't renumber (append new IDs).
- **Exact file path is mandatory** — a task with no file path is incomplete
  (❌ `- [ ] T003 [US1][dev] Create endpoint` — missing path).
- **`[P]`** only when the task touches different files and has no dependency on an incomplete task.
- Sub-bullets under a task may add detail (subtasks, estimate, AC refs, tests) but the checkbox
  line itself carries ID + tags + path.

## Phase Structure (user-story-driven, adaptive)

Organize tasks so each user story is an **independently testable vertical slice** (aligns with the
PRD's prioritized P1/P2/P3 stories and GSD thin slices):

1. **Phase 1 — Setup:** scaffolding, tooling, project skeleton. (no `[US]` tag)
2. **Phase 2 — Foundational (blocking):** shared prerequisites needed by multiple stories
   (schema/migrations, shared modules). (no `[US]` tag)
3. **Phase 3…N — one phase per user story, in priority order (P1 first):** each phase delivers a
   working, testable slice of that story. Tasks tagged `[USk]`.
4. **Final Phase — Polish / cross-cutting:** rate limiting, docs, hardening. (no `[US]` tag)

**Adaptive fallback:** when the PRD has no meaningful user stories (e.g., a pure `[sre]`/infra or
`[data]` spec), fall back to **dependency/deployment phases** (Phase 1, 2, 3 by ordering) and omit
`[US]` tags. Don't force user stories where they don't exist.

A user-story phase **is** a phase for the orchestrated `/run` §6 implementation gate — keep phases
coherent so the gate runs between slices.

## Tasks Template (Required Order)

### 1. Header with Metadata

```markdown
---
name: {slug}
last-updated: {YYYY-MM-DD}
status: draft
workflow: tasks-done
spec-ref: spectech.md
prd-ref: prd.md
---
```

- `status`: implementation lifecycle — `draft` (initial) → `in-progress` (set by `/dev`/`/sre`/`/data` when work begins) → `review` (set when all tasks `[x]`) → `completed` (set by `/qa` on approval) → `archived` (if superseded). Mirrors the spec.md lifecycle so the same status guards apply to both workflows.

### 2. Title (H1)

Task breakdown title (same as project/feature name)

### 3. ## Overview

- Total estimated effort · number of tasks · user stories / phases · key dependencies
- Structure used: **user-story-driven** or **dependency-phased** (fallback), and why

### 4. ## Task List

User-story-driven phases with the normative line format:

```markdown
## Phase 1: Setup
- [ ] T001 [dev] Scaffold trial module structure (src/trial/)

## Phase 2: Foundational (blocking)
- [ ] T002 [dev] Create trials table + migration (db/migrations/001_trials.sql)
  - Complexity: S · Covers: FR-1
  - Indexes on (user_id, email); reversible migration

## Phase 3: US1 — Start free trial (P1)
- [ ] T003 [US1][dev][P] POST /api/trials endpoint (src/routes/trial.ts)
  - Complexity: M · Covers: AC-1, AC-4
  - Input validation, duplicate check, unit tests (80%+)
- [ ] T004 [US1][dev] Trial creation logic (src/service/trial-service.ts)
  - Complexity: M · Covers: AC-1
- [ ] T005 [US1][sre] Backup for trials table (infra/backup.tf)
  - Complexity: S

## Phase 4: US2 — View trial status (P2)
- [ ] T006 [US2][dev] GET /api/trials/:id (src/routes/trial.ts)
  - Complexity: S · Covers: AC-2, AC-3

## Phase 5: Polish / cross-cutting
- [ ] T007 [dev] Rate limiting on trial creation (src/mw/rate-limit.ts)
  - Complexity: S · Covers: security requirement
```

### 5. ## Effort Summary

| Phase / Story | [dev] | [sre] | [data] | Est. Days | Risk |
|---------------|-------|-------|--------|-----------|------|
| Setup + Foundational | 4pts | — | — | 2 | Medium |
| US1 (P1) | 8pts | 2pts | — | 3 | Medium |
| US2 (P2) | 4pts | — | — | 2 | Low |
| Polish | 2pts | — | — | 1 | Low |
| **Total** | **18pts** | **2pts** | — | **8** | — |

### 6. ## Dependencies & Ordering

- Phase order: Setup → Foundational → US1 → US2 → Polish (each `[USk]` phase independently testable).
- Task deps by ID: `T003 → T002` (endpoint needs table); `T006 → T004`.
- Parallelizable (`[P]`): T003 and T005 can run together (different files).
- Critical path: T002 → T004 → T003 → T006.

### 7. ## Testing per Task

Each task names its tests (test-first where the project uses TDD):

```markdown
### T002 — Create trials table
- [ ] Unit: schema validates fields; migration applies + rolls back
- [ ] Integration: table accessible after migration
```

### 8. ## Coverage Map

Traceability — this is what the review gate (plan-reviewer, folder mode) checks. **Every PRD AC and
every user story maps to ≥1 task; every task maps back to a requirement (no orphans).**

| Source (PRD AC / User Story / spectech component) | Task IDs | Notes |
|---------------------------------------------------|----------|-------|
| US1 / AC-1 Start trial | T003, T004 | + E2E happy path |
| AC-2, AC-3 View status | T006 | |
| FR-1 trials persistence | T002 | |
| Security: rate limiting | T007 | |

- Coverage gaps (AC/story with no task): {list or "none"}
- Orphan tasks (no mapped requirement): {list or "none"}

### 9. ## Implementation Notes

- Migrations idempotent/reversible; email templates version-controlled
- Notification job retryable (queue); trial expiration in UTC

### 10. ## Known Risks & Gotchas

- **Timezone**: expiration in UTC · **Email delivery**: no timing guarantee → manual override
- **Concurrent signups**: DB unique constraint · **GDPR**: trial purge job

---

## Quality Bar Before Handoff

- [ ] Every task has a stable ID, domain tag, and exact file path
- [ ] Story-phase tasks carry a `[US]` tag; Setup/Foundational/Polish do not
- [ ] Structure is user-story-driven (or dependency-phased with a stated reason)
- [ ] Every PRD acceptance criterion and user story maps to ≥1 task (Coverage Map)
- [ ] No orphan tasks; no `[NEEDS CLARIFICATION]` / TBD / TODO; no undefined-file references
- [ ] Effort/complexity estimated; dependencies stated by task ID
- [ ] Testing specified per task; `[P]` used only for truly parallel tasks
- [ ] No task too large (>5 days → break down)
- [ ] File saved to `docs/specs/{slug}/tasks.md`; `_state.json.steps.tasks` updated to `"done"`
      (ready-for-dev tracked there too) and a matching `_notes.md` entry appended — per the
      `ticket-workflow` skill (the only control-file convention; no other metadata file is
      created)

---

## Notes

- **User-story slices** — prefer organizing by the PRD's prioritized stories so each is an
  independently shippable, testable increment (GSD thin vertical slices)
- **Stable IDs** — `T001…`; reference them in chats/deps/coverage; never renumber on edit
- **One task = implementable in 1–5 days** — if larger, break it down
- **Tag correctly** — `[dev]` app code, `[sre]` infra, `[data]` data work; multi-repo `[dev:repo]`
- **Map everything** — every AC/story → a task; every task → a requirement (no orphans)
- **Think testing first** — each task names its tests
