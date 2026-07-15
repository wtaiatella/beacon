### ROAD-51: Context-Aware Artifact Sharing (Least Privilege Protocol)

**Priority:** High  
**Category:** Architecture / Security  
**Status:** Completed
**Complexity:** Medium  
**Dependencies:** ROAD-47, ROAD-50

#### Description
As the pipeline grows more complex with specialist agents and session persistence, there is a high risk of context bloat if every agent receives the entire session memory. This roadmap item implements a "Least Privilege" artifact sharing protocol. The Orchestrator will route specific artifact files (reports, diffs, briefs) *only* to the personas that explicitly require them for their domain, keeping context windows small, focused, and token-efficient.

#### Goal
- **Standardized Artifact Storage:** Establish a predictable directory structure within `docs/sessions/<id>/` for intermediate artifacts (e.g., `/mcp`, `/scanners`, `/diffs`).
- **Least Privilege Matrix:** Define strict producer-to-consumer relationships for all 24 agents to prevent cross-contamination of context.
- **Orchestrator Routing:** Update the `run-pipeline` skill to explicitly inject only authorized artifacts into `Task()` prompts, clearing unrelated history between phases.

#### Detailed Workflow to Audit & Enforce

**1. The Artifact Storage Matrix**
Update the Orchestrator to save outputs into distinct, namespaced session folders instead of a single `current.md` dump:
- `artifacts/mcp-briefs/` (produced by `mcp-*`)
- `artifacts/explorer/` (produced by `codebase-explorer`)
- `artifacts/scanners/` (produced by `security-scanner`, `spec-validator`)
- `artifacts/diffs/` (produced by git scripts during review phases)
- `artifacts/qa-report.md` (produced by `qa`)

**2. The Least Privilege Injection Rules**
Update `run-pipeline/SKILL.md` to enforce the following strict context boundaries during task delegation:
- **`Task(plan)`:** Receives `artifacts/mcp-briefs/` and `artifacts/explorer/`. Does NOT receive raw code diffs or scanner reports.
- **`Task(dev|sre|data)`:** Receives the Spec. Receives `artifacts/explorer/` *only* if they issued a `REQUEST_MAIN` for it. Does NOT receive MCP briefs or QA reports.
- **`Task(*-reviewer)`:** Receives the Spec and ONLY their specific domain's `artifacts/diffs/` (e.g., `data-reviewer` cannot see `sre` infrastructure diffs).
- **`Task(qa)`:** Receives the Spec, `artifacts/scanners/` (security/validator), and high-level cross-domain diffs. Does NOT receive the raw conversational transcripts from the implementer agents.
- **`Task(summary)` & `Task(scrum)`:** Receives ONLY the final `artifacts/qa-report.md` and reviewer gate scores. Does NOT receive code diffs, scanner raw outputs, or codebase maps.

**3. Context Wiping (The Airgap)**
- Between pipeline phases (e.g., moving from Implementation to QA), the Orchestrator must actively drop previous file contexts from the payload so the `qa` agent isn't burdened with the `dev` agent's debugging history.

#### Deliverables
- [ ] **Folder Architecture:** Update `session-init.sh` to scaffold the `artifacts/` subdirectories.
- [ ] **Skill Update:** Rewrite the `run-pipeline/SKILL.md` phase transitions to enforce the Least Privilege Injection Rules matrix.
- [ ] **Agent Prompt Cleanup:** Update the reviewer and QA `.md` files to expect these specific artifact payloads from the orchestrator.
- [ ] **Audit Verification:** Use the `audit-session-trace.py` (ROAD-40/49) to prove that the `qa` agent's transcript specifically excludes `mcp-briefs` and `dev` chat history.