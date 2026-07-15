### ROAD-26: Glean Enterprise Search Integration

**Priority:** Medium
**Category:** Integration
**Status:** Completed
**Complexity:** Medium
**Dependencies:** Glean MCP server or API access

#### Description

Integrate Glean enterprise search as a context source for agents, complementing code-level knowledge (ARC MCP) with broader organizational knowledge: design documents, Slack threads, wiki pages, incident postmortems, and cross-team decisions. Agents can search Glean to find institutional context that doesn't live in code repositories.

#### Key Deliverables

- [x] Configure Glean MCP server (or REST API adapter) in `.cursor/mcp.json`
- [x] Define search tool conventions: when agents should query Glean vs. ARC MCP vs. local codebase
- [x] Update `/plan` agent to search Glean for prior art, related design docs, and past architectural decisions before drafting specs
- [x] Update `/fix` agent to search Glean for incident history, related Slack threads, and runbooks when diagnosing issues
- [x] Update `/qa` agent to search Glean for compliance requirements, security advisories, and team conventions
- [x] Document Glean search best practices in router rule or conventions (query construction, result interpretation, when to use which source)

#### Notes

- Glean indexes across Google Workspace, Slack, Confluence, Jira, GitLab, and other connected sources -- it provides the "institutional memory" layer that code-focused tools miss.
- Auth will likely require SSO/OAuth integration; configuration should be per-workspace.
- Start read-only: agents search Glean for context. Writing back to Glean (if applicable) is a separate concern.
- Evaluate Glean's MCP plugin for Cursor if available; otherwise build a thin MCP adapter over Glean's REST API.

---
