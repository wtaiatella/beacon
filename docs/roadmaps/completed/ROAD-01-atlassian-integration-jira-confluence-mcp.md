### ROAD-01: Atlassian Integration (Jira + Confluence MCP)

**Priority:** High
**Category:** Integration
**Status:** Completed
**Complexity:** Large
**Dependencies:** Atlassian MCP plugin or API access

#### Description

Bidirectional integration with Atlassian tools (Jira and Confluence) so agents can read and write project management context. Phased approach: start with read-only search via Atlassian's MCP plugin, then add write-back capabilities through a `/sync` subagent.

**Phase 1 (read-only)** is tracked by **`2026-04-10-road-01-atlassian-read-only-spec.md`**: documentation, `.cursor/mcp.json` template, onboarding, and persona Toolbox hints — **no** Jira/Confluence agent writes. **Phase 2** (write-back, `/sync`) remains **Planned**; optional **`/run --sync`** is **ROAD-12**.

#### Phase 1: Read-Only Context (MCP Plugin)

- [x] Configure Atlassian MCP server in `.cursor/mcp.json` (evaluate Atlassian Rovo MCP plugin for Cursor, or build adapter over Atlassian REST API)
- [x] `/plan` reads linked Jira epics/stories for requirements, acceptance criteria, and priority context before drafting specs
- [x] `/fix` searches Jira for related bug reports, known issues, and workarounds when diagnosing problems
- [x] `/qa` searches Confluence for test plans, compliance checklists, and team standards during review
- [x] Agents search Confluence for architecture decision records (ADRs), runbooks, and onboarding docs

#### Phase 2: Bidirectional Sync (/sync subagent)

- [ ] `/sync` subagent (`.cursor/agents/sync.md`) for explicit push/pull operations
- [ ] Story-to-Spec: pull Jira story fields (summary, description, acceptance criteria, labels, priority) into spec context
- [ ] Spec-to-Story: update Jira story status, comments, and labels from spec task completion
- [ ] Spec-to-Confluence: push spec sections, architecture diagrams, and task lists to a linked Confluence page
- [ ] Review report upload: attach `/qa` review reports to the linked Confluence page
- [ ] `/run --sync` integration (see ROAD-12): auto-invoke `/sync` at pipeline completion

#### Key Deliverables

- [x] Atlassian MCP server entry template in `.cursor/mcp.json`
- [x] Auth configuration guide (API tokens, OAuth, Atlassian Forge app) — see `docs/reference/atlassian-cursor-workflow.md`
- [ ] Project/space mapping configuration (which Jira project maps to which workspace repo, which Confluence space holds specs)
- [ ] `/sync` subagent with structured sync operations

#### Notes

- Phase 1 can ship independently using Atlassian's MCP plugin (if mature enough) or a thin REST adapter. No custom server needed for read-only.
- Phase 2 requires an org-owned MCP server or Atlassian Forge app for write-back. Auth model and project/space mapping should be configurable per workspace.
- The ARC pipeline already auto-generates Confluence pages for project indexes (ROAD-25) -- coordinate to avoid duplication.
- Evaluate Atlassian Rovo Agent and Forge platform capabilities for deeper integration.

---
