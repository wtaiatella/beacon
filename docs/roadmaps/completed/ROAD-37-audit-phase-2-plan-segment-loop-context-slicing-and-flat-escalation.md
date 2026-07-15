### ROAD-37: Audit Phase 2 - Plan Segment, Loop Context Slicing & Flat Escalation

**Priority:** High
**Category:** Architecture / Orchestration
**Status:** Completed
**Complexity:** Large
**Dependencies:** ROAD-36

#### Description

Audit the architecture specification drafting phase (`/plan`). This phase is the critical bridge between discovery and execution. The audit must verify that the orchestrator enforces the self-healing review loop without causing context bloat, strictly prevents the `plan` agent from spawning nested scouting agents, and ensures that `Task(scrum)` acts as the sole authorization gate for spec mutations.

#### Detailed Workflow to Audit & Enforce

The audit must verify that the Main Agent executes the following sequence precisely:

**1. Context Injection & Initial Draft**
- The Main Agent delegates `Task(plan)` to draft the architecture spec.
- **Constraint (Context Minimization):** The orchestrator must inject *only* the condensed `merged-brief.md` (from Phase 1) and any explicitly referenced `ROAD-NN` text. It must completely omit the raw logs of the MCP tools and the orchestrator's own internal reasoning steps.

**2. Anti-Nesting Escalation (`REQUEST_MAIN:`)**
- If the `plan` agent encounters a completely unfamiliar codebase area and needs a scout, it is strictly forbidden from invoking `Task(codebase-explorer)`.
- **Enforcement:** It must output a `REQUEST_MAIN:` or `QUESTION:` payload. The Main Agent must catch this, pause the plan execution, delegate `Task(codebase-explorer)` itself, merge the results, and return them to the `plan` agent.

**3. The Plan-Review Gate**
- After `plan` outputs the draft, the Main Agent delegates `Task(plan-reviewer)`.
- `plan-reviewer` scores the spec against the threshold (default 75% or custom spec frontmatter).

**4. The Self-Healing Loop & Context Slicing**
- If the score is below the threshold, the Main Agent initiates a rework loop.
- **Persistence:** The orchestrator writes `PLAN_REVIEW_FEEDBACK:` to `docs/sessions/<id>/current.md`.
- **Constraint (Context Slicing):** When the Main Agent re-delegates `Task(plan)` for an amendment, it MUST inject *only* the isolated `PLAN_REVIEW_FEEDBACK` delta. It must explicitly strip out the chat history of the failed first attempt to prevent the LLM's context window from ballooning and degrading in quality.

**5. Loop Cap & Human Escalation**
- The orchestrator must track the loop count against `--max-plan-iterations` (default 3).
- **Enforcement:** If iteration 3 fails, the orchestrator MUST NOT loop a fourth time. It must halt and trigger an `AskQuestion` (or numbered chat fallback) to the user with options: Proceed Anyway, Abort, or Provide Guidance.

**6. Scrum Authorization & File Mutation**
- Once `plan-reviewer` passes the draft (or the human overrides), the Main Agent delegates `Task(scrum)`.
- `scrum` evaluates the final report and outputs a decision (`PROCEED`, `REWORK`, `ASK_USER`).
- **Mutation Boundary:** The `plan` agent does NOT update the spec file's `status` or tracking checkboxes. *Only* the Main Agent is permitted to physically edit the `docs/specs/*` frontmatter (e.g., to "Ready") upon receiving a `PROCEED` from `scrum`.

**7. The Manual Gate Pause (Optional)**
- If the `/run --manual` flag is active, the Main Agent must pause immediately after the Scrum `PROCEED` and trigger an `AskQuestion` (Proceed / Force Review / Add Context) before launching Phase 3 implementation.

#### Deliverables & Test Cases

- [ ] **Test Anti-Nesting:** Prompt a `/run` that forces the planner to explore an un-indexed directory. Verify the `plan` agent uses `REQUEST_MAIN:` and the orchestrator handles the `codebase-explorer` delegation.
- [ ] **Test Context Slicing:** Force a `plan-reviewer` failure. Inspect the orchestrator's payload on loop #2. Verify it contains the isolated feedback and not the raw transcript of loop #1.
- [ ] **Test the Loop Cap:** Hardcode a `plan-reviewer` to always fail. Verify the pipeline stops exactly at iteration 3 and prompts the user via `AskQuestion`.
- [ ] **Test Scrum Authority:** Monitor file I/O during the plan segment. Prove the spec file's `status` frontmatter is untouched until the exact moment `Task(scrum)` returns `PROCEED`.

---
