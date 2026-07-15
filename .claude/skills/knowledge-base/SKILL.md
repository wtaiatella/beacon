---
name: knowledge-base
description: "DEPRECATED for new projects in favor of ARC MCP (AvaTax Release Central)—see docs/reference/arc-mcp-workflow.md. Retained for output structure when /kb is used as a fallback for repos not onboarded to ARC. Defines knowledge/{project}/ layout and conventions."
---

# Knowledge Base

**Status:** For **new** AvaTax-related projects, prefer **ARC MCP** and Release Central onboarding over building a local tree. This skill documents the **legacy local** format for **fallback** maintenance and for repos outside ARC.

## When to Use

- When running **`/kb`** for a repo **not** onboarded to ARC (or as an explicit local fallback)
- When refreshing an existing **local** knowledge base after major restructuring (rare)
- When **`/summary`** runs with **`KNOWLEDGE_LOCAL_PATCH=1`** or explicit user request to patch local section files (legacy only—not the default)

The output is a set of structured markdown files that downstream agents (`/plan`, `/dev`, `/sre`, `/data`, `/qa`) may load selectively when **local** `knowledge/{project}/` is in use alongside or instead of ARC.

## Output location and naming

- **Directory:** `knowledge/{project-directory-name}/` at the workspace root (tracked in git).
- **One folder per project.** Contains multiple focused files, not one monolith.
- **Agents load only what they need** — the index is always loaded, other sections on demand.

## Folder structure (required)

```
knowledge/{project}/
├── _index.md          # always loaded — overview, stack, structure (~30-50 lines)
├── architecture.md    # components, patterns, request/data flows
├── api.md             # endpoints, auth, contracts (omit if no API surface)
├── data-models.md     # schemas, entities, migrations (omit if no persistent data)
├── dependencies.md    # runtime deps, external services, integrations
├── infrastructure.md  # CI/CD, containers, deployment model, environments
└── conventions.md     # naming, error handling, logging, config patterns
```

### Which files agents load

| Agent | Loads | Why |
|-------|-------|-----|
| `/plan` | `_index.md` + sections relevant to the feature scope | Needs enough to architect, not everything |
| `/dev` | `_index.md` + `conventions.md` + `api.md` (if API work) | Coding patterns and contracts |
| `/sre` | `_index.md` + `infrastructure.md` + `dependencies.md` | Infrastructure context |
| `/data` | `_index.md` + `data-models.md` + `dependencies.md` | Schema and integration context |
| `/qa` | `_index.md` (overview only) | Just needs to know what the project is |

## File formats

### `_index.md` (always loaded, keep under 50 lines)

```markdown
# {Project Name}
<!-- last-refreshed: {YYYY-MM-DD} -->

> {One-line description.}

**Type:** API service | web app | library | CLI | data pipeline | etc.
**Stack:** {language} {version} + {framework} {version}
**Package Manager:** npm | pip | go mod | etc.

## Structure
{Brief tree of top-level directories with purpose — 10-15 lines max}

## Entry Points
- Main: `src/index.ts`
- Config: `config/`
- Tests: `tests/`
```

### Section files (load on demand, each 50-150 lines)

Each section follows the structure described below. Keep them focused:

- **architecture.md**: Component diagram (Mermaid or text), request/data flow, patterns, key design decisions.
- **api.md**: Endpoints grouped by resource, auth pattern, key request/response shapes. Skip if no API.
- **data-models.md**: Core entities, relationships, DB type, migration approach. Skip if no persistent data.
- **dependencies.md**: Top runtime deps with purpose, external services, internal service dependencies.
- **infrastructure.md**: Containerization, CI/CD pipeline structure, deployment model, IaC presence.
- **conventions.md**: Naming, error handling, logging, configuration management, code organization.

## Update model

1. **Primary (AvaTax / Release Central):** Onboard repos in **`avatax-release-central`** and use **ARC MCP** for curated search—see **`docs/reference/arc-mcp-workflow.md`**. No local folder required for that path.
2. **Full local build (`/kb`):** Expensive fallback when ARC is not used. Run manually on first onboarding or after major restructuring. Not part of the regular pipeline.
3. **Incremental local patch (`/summary`, legacy):** Only when **`KNOWLEDGE_LOCAL_PATCH=1`** or the user explicitly asks; otherwise **`/summary`** does **not** patch local KB by default.

## Quality guidelines

- **Index under 50 lines.** Section files 50-150 lines each. Total KB per project: 300-700 lines across all files, but agents only load the 80-200 lines they actually need.
- **Be specific:** "Express 4.21 with Passport JWT" beats "Node.js web framework."
- **Reference files:** Point to paths: "Auth middleware at `src/middleware/auth.ts`."
- **Condense, don't copy.** Summarize patterns, don't paste code.
- **Mark uncertainty.** Say "unclear" rather than guessing.
- **Preserve section 9-equivalent notes** in each file (manual annotations at the bottom under `## Notes`).
