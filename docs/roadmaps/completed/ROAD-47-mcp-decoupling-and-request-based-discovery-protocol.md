### ROAD-47: MCP Decoupling & Request-Based Discovery Protocol

**Priority:** High  
**Category:** Architecture / Security  
**Status:** Completed
**Complexity:** Medium  
**Dependencies:** ROAD-36, ROAD-38, ROAD-44

#### Description

To maintain strict context minimization and flat orchestration, implementation personas (dev, sre, data, qa, fix) must be decoupled from direct MCP tool access. Currently, many agents have "Optional MCP" blocks that allow them to perform ad-hoc enterprise searches. This roadmap item scrubs those permissions and implements a protocol where implementers must explicitly request missing context via the Orchestrator, which then delegates to specialized MCP agents (mcp-glean, mcp-jira, etc.).

#### Goal

- **Persona Scrubbing:** Remove all "Optional MCP" sections and direct tool permissions from implementation agent definitions.
- **Protocol Implementation:** Enforce the `REQUEST_MAIN: [MCP_TYPE] [QUERY]` pattern for implementers when they identify missing context.
- **Orchestrator Awareness:** Update the Main Agent to catch these requests, delegate to the specific MCP specialist, save the result to the session folder, and re-feed the context into the implementation task.

#### Detailed Workflow to Audit & Enforce

**1. Persona Audit & Tool Removal**
- Audit `.cursor/agents/dev.md`, `qa.md`, `sre.md`, `data.md`, and `fix.md`.
- **Action:** Delete the "Toolbox" sections referring to Glean, Atlassian, and GitLab MCPs.
- **Enforcement:** Ensure their YAML `description` or system prompt explicitly states: "You have no direct access to enterprise MCPs. If context is missing, output `REQUEST_MAIN: [Glean|Jira|Confluence|GitLab] <query>`."

**2. The Discovery Escalation Loop**
- Update `run-pipeline/SKILL.md` § 5 (Implementation):
  - If an implementation agent returns a `REQUEST_MAIN` or `QUESTION` regarding enterprise context:
    1. The Main Agent identifies the required specialist (e.g., `Task(mcp-jira)`).
    2. The Main Agent executes the specialist task and saves the output to `docs/sessions/<id>/pre-plan/specialists/`.
    3. The Main Agent re-delegates the implementation task, injecting the new file into the prompt.

**3. Integration with Self-Healing (§ 4 & 6)**
- Update the **Reviewer** personas (`plan-reviewer`, `dev-reviewer`, etc.).
- If a reviewer identifies that an implementation failed due to missing external information, the reviewer should explicitly "Reject" and instruct the Main Agent to fetch the missing MCP data before the next rework attempt.

#### Deliverables

- [ ] **Scrub Personas:** Remove direct MCP access from all implementation-tier `.md` files.
- [ ] **Update Skill Logic:** Modify `run-pipeline/SKILL.md` to handle mid-run MCP discovery requests.
- [ ] **Verification:** Run a `/run` where the `dev` agent is forced to ask for a Jira ticket. Verify the Main Agent stops, calls `mcp-jira`, and then resumes `dev` with the new context.
- [ ] **Linter Update:** Update `scripts/tools/lint-check.sh` to flag any non-specialist agent definition that includes MCP tool descriptors.

#### Notes

- This turns enterprise context into a "Dependency" that is explicitly resolved, rather than a "Side Effect" of an agent's individual initiative.