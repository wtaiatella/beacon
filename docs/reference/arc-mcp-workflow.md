# ARC MCP workflow with Cursor (optional AvaTax Release Central knowledge) — ROAD-25

This workspace treats the **AvaTax Release Central (ARC)** MCP server as an **optional**, **read-only** source of **project-scoped** curated knowledge: ALFA RAG–backed search over Release Central indexes (platform, schema, per-project and per-feature corpora). Agents **do not** mutate Release Central, GitLab pipelines in `avatax-release-central`, or Confluence from this repo’s guidance—**retrieval only**. Core personas and **`/run`** steps **never depend** on ARC; if MCP tools are absent or fail, workflows continue with local **`knowledge/{project}/`**, **`codebase-explorer`**, and repo search per **`00-workspace-router.mdc`**.

**Onboarding new repos** into ARC happens in the **`avatax-release-central`** repository (`projects_config.py`, `feature_registry.py`) and related Confluence indexes—not in agentic-workspace alone. See **`docs/arc-onboarding.md`** (full split: Cursor vs server-side) and **`docs/roadmaps/`** (e.g. **`ROAD-25-arc-mcp-knowledge-base-integration.md`** under **`completed/`** when shipped).

## Two lanes (pre-plan vs in-session)

ARC fits **two** orchestration patterns — both are valid; they solve different problems:

| Lane | Who | When | Role |
|------|-----|------|------|
| **(A) Pre-plan** | Main **`/run`** session | After **`Task(pre-plan-triage)`** lists ARC / AvaTax / RC / schema / catalog needs, **before** **`Task(plan)`** | **`Task(mcp-arc)`** runs **in parallel** with other **`Task(mcp-*)`** specialists; merged, capped brief becomes **`Pre-plan context:`** for **`Task(plan)`**. **Flat** orchestration only — do **not** nest **`Task(mcp-arc)`** inside **`Task(plan)`**. |
| **(B) In-session** | **`/plan`**, **`/kb`** (where applicable) — each in its **own** session | Standalone persona work when ARC helps | Call ARC MCP tools **directly** for repo-scoped discovery. **Not** a substitute for lane (A) when triage already said ARC was needed for **`/run`** — still run pre-plan **`Task(mcp-arc)`** for the bounded external brief. |
| **Orchestrated `/run` — implementers & debug** | **`/dev`**, **`/fix`** under the pipeline | Same run as lane (A) or mid-run follow-up | **Do not** call ARC MCP **directly**. Return **`REQUEST_MAIN: ARC <query>`**; the **`/run`** main session runs **`Task(mcp-arc)`**, persists output, and re-delegates with the saved context (see **`run-pipeline`** — **Mid-run enterprise context**). |

Lane **(B)** does **not** extend to **`/dev`** or **`/fix`** when they are invoked under orchestrated **`/run`** — that path uses **`REQUEST_MAIN`** + **`Task(mcp-arc)`** (ROAD-47), not direct MCP calls in the persona session.

See **`docs/run-pipeline-reference.md`** (Pre-plan MCP gather), **`00-workspace-router.mdc`** (Supporting Subagents, MCP pre-plan), and **[mcp-servers-inventory.md](mcp-servers-inventory.md)** for server keys and tool categories.

## Purpose

| Need | Use ARC for |
|------|-------------|
| AvaTax platform / TCS / pipeline context | `search_avatax_knowledge`, `search_arc_knowledge` |
| SQL Server schemas (tables, SPs, views) | `search_database_schema` |
| A specific onboarded project group | `search_proj_{group}` |
| A specific tax feature area | `search_feat_{slug}` |

Prefer **local codebase tools** (`Read`, `Grep`, `SemanticSearch`) for **this repository’s** current files. Use **Glean** for org-wide prior art outside Release Central; **ARC** does not replace Glean for Slack/Confluence-wide search.

## Project-level ARC MCP (`.cursor/mcp.json`)

The committed entry uses **Streamable HTTP** (`type: http`) and the **gamma** endpoint (trailing slash as required by the server):

| Field | Value |
|-------|--------|
| **URL** | `https://avatax-release-central.gamma.int.us-west-2.aws.avalara.io/api/kb/mcp/` |

**JSON in `.cursor/mcp.json` has no comments.** Do not commit API tokens or passwords.

### Environment variables

| Variable | Purpose |
|----------|---------|
| **`ARC_MCP_TOKEN`** | Optional bearer token for `Authorization` when the ARC HTTP endpoint requires authentication. Set in your shell profile or a **local** env file that is **not** committed. If your org uses a different header name or OAuth-only flow, adjust **`headers`** in a **local** override of `mcp.json` (or global `~/.cursor/mcp.json`) per platform guidance—**never** commit secrets. |

The default template uses:

```json
"headers": {
  "Authorization": "Bearer ${env:ARC_MCP_TOKEN}"
}
```

If the server allows unauthenticated access in your environment, you may use **`"headers": {}`** (same pattern as **`glean_default`** in this repo) instead of the bearer line—verify with ARC platform owners.

### Not using ARC

Remove the **`avatax-release-central`** block from **`mcpServers`** in **`mcp.json`** (JSON has no comments—you cannot “comment out” a block). Personas and skills work without it.

### Requirements (typical)

- Network reachability to the gamma host (VPN / corporate network as required by your org).
- Valid credentials when the server enforces auth (`ARC_MCP_TOKEN` or org-approved OAuth/header setup).

## Tool catalog (roadmap-aligned)

Exact tool names and parameters **must** be verified in Cursor (**Settings → MCP**) after connecting; the server may rename or extend tools.

| Tool | Description |
|------|-------------|
| `search_arc_knowledge` | ARC domain knowledge: modules, project catalog, tax feature registry |
| `search_avatax_knowledge` | AvaTax platform knowledge: TCS internals, GetTax pipeline, ops runbooks |
| `search_database_schema` | SQL Server schemas: tables, columns, indexes, FKs, views, stored procedures |
| `search_proj_{group}` | Per-project-group search (e.g. multiple groups such as tcs, cross-border, tcs-deps—verify live list) |
| `search_feat_{slug}` | Per-feature search (e.g. dynamic-rules, vat, sst, nexus—verify live list) |

## Read-only guardrails

- **Do:** Call ARC MCP tools for **read** search and context when the task benefits from Release Central indexes.
- **Do not:** Use agents to **write** to Release Central, trigger GitLab pipelines, or change `projects_config.py` / `feature_registry.py` from automated runs under this workspace policy—those belong to normal engineering workflows and the `avatax-release-central` repo.

## Degradation when offline or misconfigured

| Situation | Behavior |
|-----------|----------|
| ARC block missing from `mcp.json` | No ARC tools; use local KB, `codebase-explorer`, Grep/SemanticSearch. |
| Connection errors / 401 / timeout | Retry once; then fall back as above. Do not block **`/plan`**, **`/kb`**, standalone **`/dev`** / **`/fix`**, or **`/run`** on ARC. Under orchestrated **`/run`**, **`/dev`** / **`/fix`** escalate ARC via **`REQUEST_MAIN`** — the orchestrator runs **`Task(mcp-arc)`**. |
| Empty or irrelevant results | Narrow the query; try a different tool; fall back to repo + local `knowledge/`. |

## Reference docs

| Doc | Purpose |
|-----|---------|
| [mcp-servers-inventory.md](mcp-servers-inventory.md) | All **`mcp.json`** servers — tools (from descriptors), read vs write, `Task(readonly)` note |
| [cursor-mcp.md](cursor-mcp.md) | MCP transports, `${env:…}`, security |
| [glean-cursor-workflow.md](glean-cursor-workflow.md) | Org-wide search (complementary to ARC) |
| [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) | Optional GitLab MCP (read-only usage) |

## Manual verification checklist

See **`docs/arc-onboarding.md`** (section **Manual verification checklist**) for the full ROAD-25 workspace checklist (Init text, agent coherence, grep sanity for stale `/kb`-only messaging, and policy).
