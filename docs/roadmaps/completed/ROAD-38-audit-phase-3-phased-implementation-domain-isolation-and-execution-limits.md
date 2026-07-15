### ROAD-38: Audit Phase 3 - Phased Implementation, Domain Isolation & Execution Limits

**Priority:** High
**Category:** Architecture / Orchestration
**Status:** Completed
**Complexity:** Large
**Dependencies:** ROAD-37

#### Description

Audit the core execution engine of the `/run` pipeline (`dev`, `sre`, `data`). This phase carries the highest risk for context bloat, race conditions, and unauthorized file mutations. The audit must verify that the Main Agent strictly enforces `### Phase N:` sequential boundaries, isolates domain context to enforce "least privilege", runs tracks in parallel, and strictly forbids execution agents from mutating the spec file directly.

#### Detailed Workflow to Audit & Enforce

The audit must verify that the Main Agent executes the following sequence precisely:

**1. Phase Slicing & Context Minimization (Least Privilege)**
- The Main Agent must parse the spec and identify `### Phase N:` boundaries. 
- **Constraint (Domain Isolation):** When preparing the payload for `Task(dev)` in Phase 1, the orchestrator MUST explicitly strip out Phase 2 tasks, AND strip out Phase 1 `[sre]` and `[data]` tasks. `dev` should only receive the exact `[dev]` bullet points it is responsible for in that exact phase to minimize context window bloat and prevent hallucinations.

**2. Parallel Execution & Anti-Nesting**
- The Main Agent delegates `Task(dev)`, `Task(sre)`, and `Task(data)` **in parallel** (using `run_in_background` + `Await`) for the current phase only. *(Note: If `--manual` is passed, they run sequentially).*
- **Constraint (Flat Orchestration):** Execution agents are strictly forbidden from nesting tasks (e.g., `dev` cannot call `dev-reviewer` or `codebase-explorer`). 
- If an agent hits a blocker, it must halt and output `QUESTION:` or `APPROVAL_NEEDED:`. The Main Agent must catch this string, pause the parallel execution safely, log it to the session folder, and prompt the human.

**3. The Mutation Guardrail ("Proposed Completions")**
- The orchestrator must inject the `[DELEGATION MODE: orchestrated]` header into every implementation prompt.
- **Enforcement:** Implementation agents MUST NOT edit `docs/specs/*` to check off `[x]` boxes, change `status`, or update `last-updated`. They must output a text block labeled **"Proposed completions"**. 

**4. Parallel Review & Scrum Phase Gate**
- After the execution tasks `Await` completes, the Main Agent delegates the matching `*-reviewer` tasks (e.g., `Task(dev-reviewer)`) in parallel for that phase.
- The Main Agent then delegates `Task(scrum)` with the aggregated reviewer scores for that single phase.

**5. Orchestrator Spec Patching & Phase Transition**
- If `Task(scrum)` returns `PROCEED`, the Main Agent (Orchestrator)—and *only* the Main Agent—physically edits the spec file to apply the "Proposed completions" (checking the `[x]` boxes).
- **Constraint:** The orchestrator MUST NOT delegate execution tasks for Phase *k+1* until Phase *k* has received a `PROCEED` from `scrum` and the spec has been patched.

**6. Session Recovery & Checkpointing**
- The Main Agent must log `GATE: impl | DONE` (or per-track logs) to `docs/sessions/<id>/current.md` as each track finishes.

#### Deliverables & Test Cases

- [ ] **Test Domain Isolation:** Execute a `/run` on a spec with both `[dev]` and `[sre]` tasks in Phase 1. Intercept the payload sent to `Task(dev)`. Verify it contains absolutely zero text related to the `[sre]` tasks.
- [ ] **Test Phase Gating:** Execute a two-phase spec. Verify the orchestrator completely finishes the Phase 1 Scrum gate and applies spec checkboxes *before* it delegates the `Task(dev)` for Phase 2.
- [ ] **Test Mutation Guardrails:** Monitor file I/O during execution. Prove that the `docs/specs/*` file modification timestamp does not change while `Task(dev)` is running, but only changes when the Main Agent patches it post-Scrum.
- [ ] **Test Session Resume:** Mid-way through Phase 2 execution, simulate a crash. Run `/run --resume` and verify the Main Agent reads the `GATE:` lines from the timestamped session folder, acknowledges Phase 1 is done, and perfectly resumes Phase 2 without repeating work.

---
