### ROAD-25: ARC MCP Knowledge Base Integration

**Priority:** High
**Category:** Integration
**Status:** Completed (2026-04-10) — workspace MCP config, agents, run-pipeline Init, router, and docs shipped per `docs/specs/2026-04-10-road-25-arc-mcp-knowledge-base-spec.md`; index/collection pipelines remain owned by **`avatax-release-central`**
**Complexity:** Medium
**Dependencies:** ARC MCP server (AvaTax Release Central, maintained by Daniel Joppi's team)

#### Description

Use the **ARC (AvaTax Release Central) MCP server** as the **primary** semantic knowledge path for AvaTax-related work: project context, tax features, database schemas, and platform knowledge via ALFA RAG indexes. The ARC pipeline incrementally builds knowledge from GitLab repos on a monthly schedule, producing structured indexes that agents can query in real time.

**Local `knowledge/{project}/`** trees and the **`/kb`** agent remain **supported as fallback** for repos not onboarded to ARC. Centralized indexes complement (and reduce reliance on) per-developer-only local KB maintenance.

**Shipped behavior in agentic-workspace:** ARC-first knowledge retrieval with **local `knowledge/{project}/`** and **`/kb`** as **fallback** for repos not in ARC; **`/summary`** default KB patching deprecated in favor of ARC + Release Central onboarding (see agent docs).

#### Key Deliverables

- [x] Configure ARC MCP server in `.cursor/mcp.json` (endpoint: `https://avatax-release-central.gamma.int.us-west-2.aws.avalara.io/api/kb/mcp/`, transport: `http`)
- [x] Update `/plan` agent to **prefer** ARC MCP tools (`search_arc_knowledge`, `search_avatax_knowledge`, `search_database_schema`, per-project and per-feature search tools) over relying **solely** on local `knowledge/{project}/` files (layered fallbacks when ARC is absent or empty)
- [x] Update `/run` orchestrator to check ARC MCP availability instead of warning about missing local KB
- [x] Update `/fix` and `/dev` agents to leverage ARC MCP for project context when investigating or implementing changes
- [x] Deprecate `/kb` agent -- mark as superseded by ARC MCP; retain as fallback for repos not yet onboarded to ARC
- [x] Deprecate `/summary` KB patching -- ARC pipeline handles incremental updates via GitLab CI
- [x] Update router rule (`00-workspace-router.mdc`) to document ARC MCP as the primary knowledge source
- [x] Document onboarding process for new projects into ARC (configure in `projects_config.py` and `feature_registry.py` in `avatax-release-central` repo) — see **`docs/arc-onboarding.md`**

#### ARC MCP Capabilities

| Tool | Description |
|---|---|
| `search_arc_knowledge` | ARC domain knowledge: modules, project catalog, tax feature registry |
| `search_avatax_knowledge` | AvaTax platform knowledge: TCS internals, GetTax pipeline, ops runbooks |
| `search_database_schema` | SQL Server schemas: tables, columns, indexes, FKs, views, stored procedures |
| `search_proj_{group}` | Per-project-group search (10 groups: tcs, cross-border, tcs-deps, etc.) |
| `search_feat_{slug}` | Per-feature search (24 features: dynamic-rules, vat, sst, nexus, etc.) |

#### Notes

- The ARC pipeline runs as a monthly GitLab scheduled pipeline with incremental collection (SHA-skip, diff-based patching). Can also be triggered manually or via API.
- Knowledge indexes are powered by ALFA RAG with hybrid context (curated root files + semantic retrieval).
- The same pipeline auto-generates Confluence pages at [AvaTax Release Central Indexes](https://avalara.atlassian.net/wiki/spaces/ATPE/pages/639240306719/AvaTax+Release+Central+Indexes).
- New projects can be onboarded by adding entries to `projects_config.py` and `feature_registry.py` in the `avatax-release-central` repo -- no changes needed in the agentic-workspace.
- Architecture reference: `avatax-release-central` repo, `docs/architecture/flow-project-context.md`.

---
