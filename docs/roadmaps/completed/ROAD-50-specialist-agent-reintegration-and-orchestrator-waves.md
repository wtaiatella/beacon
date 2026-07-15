### ROAD-50: Specialist Agent Reintegration & Orchestrator Waves

**Priority:** Medium  
**Category:** Architecture / Orchestration  
**Status:** Completed
**Complexity:** Medium  
**Dependencies:** ROAD-47

#### Description
The shift to "Flat Orchestration" successfully prevented context bloat, but it orphaned three critical read-only specialists: `codebase-explorer`, `spec-validator`, and `security-scanner`. Because implementer agents can no longer invoke them directly, the Main Agent (Orchestrator) must be formally taught how to schedule them during the pipeline waves and how to respond to `REQUEST_MAIN` calls for codebase exploration.

#### Goal
- **On-Demand Exploration:** Extend the `REQUEST_MAIN` protocol (built in ROAD-47) to allow the `plan` or `fix` agents to request `codebase-explorer` if they need directory mapping.
- **QA Wave Augmentation:** Update the Orchestrator to run `spec-validator` and `security-scanner` automatically as parallel prep-tasks right before the `qa` step, feeding their artifacts into the `qa` prompt.
- **Artifact Passing:** Ensure the Orchestrator knows how to save these specialist outputs to the session memory and inject them cleanly into the dependent persona's context.

#### Detailed Workflow to Audit & Enforce

**1. The Exploration Escalation (`codebase-explorer`)**
- Update `run-pipeline/SKILL.md` § 3 (Plan). 
- If `Task(plan)` outputs `REQUEST_MAIN: codebase-explorer <target-dir>`, the Orchestrator must pause, run `Task(codebase-explorer)`, save the output to `docs/sessions/<id>/artifacts/explorer/`, and re-feed it to `plan`.
- Update `plan.md` to instruct the agent to use this request format instead of guessing directory structures.

**2. The QA Prep Wave (§ 7.0)**
- Insert a new sub-step in the Orchestrator pipeline right before `Task(qa)`.
- The Orchestrator runs `Task(spec-validator)` and `Task(security-scanner)` in parallel.
- The Orchestrator saves their outputs to `docs/sessions/<id>/artifacts/scanners/`.
- When the Orchestrator finally delegates `Task(qa)`, it appends: *"Here are the pre-run artifacts from the security scanner and spec validator..."*

**3. Tooling Adjustments**
- Review `.cursor/agents/spec-validator.md` and `security-scanner.md`. Ensure they are configured to return clean, bounded Markdown reports suitable for injection into the `qa` context without blowing up the token count.

#### Deliverables
- [ ] **Skill Update (Plan):** Add `codebase-explorer` handling to the Orchestrator's Plan phase in `run-pipeline/SKILL.md`.
- [ ] **Skill Update (QA):** Add the "QA Prep Wave" logic to § 7 of `run-pipeline/SKILL.md`.
- [ ] **Agent Prompt Update:** Update `plan.md` and `fix.md` with instructions on how to request the codebase explorer.
- [ ] **Verification Run:** Run a pipeline. Verify the session folder contains `artifacts/scanners/` outputs and that the `qa` agent successfully references the scanner's output in its final report.