### ROAD-36: Audit Phase 1 - Init, Two-Wave Pre-Plan & Context Minimization

**Priority:** High
**Category:** Architecture / Orchestration
**Status:** Completed
**Complexity:** Large
**Dependencies:** ROAD-35

#### Description

Audit the initial discovery phase of the `/run` pipeline. This phase is critical because it establishes the Git safety boundaries, initializes the ephemeral session state machine (ROAD-35), and gathers external context. The orchestrator must execute a strict, two-wave, flat-orchestration sequence to prevent context window bloat and enforce the "least privilege" rule for downstream agents.

#### Detailed Workflow to Audit & Enforce

The audit must verify that the Main Agent executes the following sequence precisely, without deviating or nesting tasks:

**1. Git Safety & Worktree Initialization**
- The Main Agent must detect the current working branch.
- If the branch is protected (`main`, `master`, `develop`, `release/*`), the orchestrator MUST halt and prompt the user for explicit consent to create a new branch. It cannot proceed silently.
- If consent is given, it must isolate the work by creating a `git worktree` and tracking that path in the `WORKTREE_PATHS` payload.

**2. Session State Initialization**
- The orchestrator must generate a timestamped session directory (`docs/sessions/<timestamp>/`).
- It must update the `docs/sessions/ACTIVE_SESSION` pointer file.
- It must initialize the state tracker at `docs/sessions/<timestamp>/current.md`.

**3. The Triage Gate**
- The Main Agent delegates `Task(pre-plan-triage)` passing the user's goal. 
- Triage must respond with structured classifications: which MCPs belong in Wave 1, which belong in Wave 2, and any specific Jira keys or Confluence spaces required.

**4. Wave 1: Parallel Breadth (Glean & ARC)**
- The Main Agent evaluates the triage output. 
- If `glean` or `arc` are flagged, the Main Agent delegates `Task(mcp-glean)` and `Task(mcp-arc)` to run **in parallel** (`run_in_background: true` + `Await`). 
- **Constraint:** If triage flags neither, Wave 1 is completely skipped.
- **Persistence:** For each Wave 1 specialist that runs, the Main Agent saves bounded output to `docs/sessions/<id>/pre-plan/specialists/<name>.md` (e.g. `glean.md`, `arc.md`). If Wave 1 is skipped, no Wave 1 specialist files are written.
- **Merge & Gate:** The Main Agent merges available Wave 1 specialist briefs (if any) into a temporary brief and evaluates if Wave 2 is triggered.

**5. Wave 2: Gated Depth (Jira, Confluence, GitLab)**
- Wave 2 *only* fires if `Task(pre-plan-triage)` OR the Wave 1 merged brief explicitly requires it (e.g., specific ticket IDs or MR paths are found).
- If triggered, the Main Agent delegates `Task(mcp-jira)`, `Task(mcp-confluence)`, and `Task(mcp-gitlab)` (read-only mode).
- **Persistence:** Outputs are saved to the respective `specialists/*.md` files in the session folder.

**6. Context Minimization & Handoff**
- The Main Agent merges Wave 1 and Wave 2 data into a final `merged-brief.md`.
- **Constraint (Anti-Bloat):** The Main Agent MUST aggressively summarize this brief. It cannot pass raw tool dumps to the next phase. 
- The Main Agent passes *only* the condensed `merged-brief.md` (and any matching `ROAD-NN` text) into the `Pre-plan context` block of `Task(plan)`.
- **Flat Orchestration Verification:** The `plan` agent must be strictly forbidden from nesting its own `Task(mcp-*)` calls to gather more `/run` context.

#### Deliverables & Test Cases

**Documentation & automation (shipped)**

- [x] **Enforce Flat Rule (docs + CI):** `run-pipeline/SKILL.md`, `00-workspace-router.mdc`, and blocking **`scripts/tools/verify-road-36-phase1-preplan-docs.sh`** — `/plan` must not nest **`Task(mcp-*)`** for **`/run`** pre-plan MCP gather; main session owns triage + specialists.
- [x] **Aligned reference + router:** `docs/run-pipeline-reference.md` (delegation, pre-plan waves, session storage, manual verification); workspace router pre-plan bullets.
- [x] **Persistence contract:** `session-handoff.sh` + **`session-memory.sh session-root`** documented in **`docs/run-pipeline-reference.md`** (merged brief, specialists only when run, Wave 1 skip / `--skip plan` shapes).

**Manual test runbook (documented — execute in live `/run`)**

Full steps: **`docs/run-pipeline-reference.md`** — **Manual verification (ROAD-36 Phase 1)**; short pointer: **`docs/sessions/README.md`**.

| Case | Runbook documented | Manually verified (live `/run`) |
|------|:------------------:|:-------------------------------:|
| **Test Git Boundaries** — protected branch; hard-stop before Init / pre-plan / `Task(plan)` | [x] | [ ] |
| **Test Wave Isolation** — Jira-only / Wave 2-only; no `Task(mcp-glean)` / `Task(mcp-arc)` | [x] | [ ] |
| **Audit Context Bloat** — `Pre-plan context:` summarized bullets, not raw MCP JSON | [x] | [ ] |

---
