# Glean workflow with Cursor (optional enterprise search) — ROAD-26

This workspace treats **Glean** as an **optional** source of **organization-wide** context: design documents, Slack threads, wikis, incident notes, and cross-team decisions indexed in your tenant’s **Knowledge Graph**. Agents **do not** write back to Glean or to downstream systems from this repo’s guidance—**read-only** retrieval only. Core personas, skills, and **`/run`** steps **never depend** on Glean; if MCP tools are absent or fail, workflows continue using local tools and other optional MCPs per **`00-workspace-router.mdc`**.

## Supported integration paths (decision)

| Path | When to use |
|------|-------------|
| **Official Glean MCP server (remote HTTP/SSE)** | **Preferred** for most teams: tenant admin enables MCP; users connect via **Glean’s MCP Configurator** (host: Cursor), which emits a **tenant-specific** URL and OAuth or token setup. See [About Glean MCP server](https://docs.glean.com/administration/platform/mcp/about) and [Using the Glean MCP Server](https://docs.glean.com/user-guide/mcp/usage). |
| **Glean plugin for Cursor (marketplace)** | Install from **Cursor Settings → Marketplace** → search **“Glean”** ([Glean Plugin for Cursor](https://developers.glean.com/guides/mcp/cursor)). The plugin still relies on a **Glean MCP connection**—use the **MCP Configurator** for Cursor to obtain the server endpoint and complete authentication. |
| **Thin stdio MCP adapter over Glean REST** | **Not shipped** in this repo; only if your tenant blocks hosted MCP and your org maintains a proxy—treat as a follow-up spike with its own spec. |

**JSON in `.cursor/mcp.json` has no comments.** Use the exact snippet shape from the Configurator (or this doc’s example with **`${env:GLEAN_MCP_URL}`**) rather than inline comments.

## Project-level Glean MCP (`.cursor/mcp.json`)

This repo may include an optional **`Glean`** entry in `.cursor/mcp.json`. The **URL is tenant-specific**—do not copy a hostname from another organization.

**Recommended committed shape** (URL from your run of [Open MCP Configurator](https://app.glean.com/settings/install?mcpConfigure=true&mcpHost=cursor), stored in an environment variable—see [`cursor-mcp.md`](cursor-mcp.md) interpolation):

```json
"Glean": {
  "type": "http",
  "url": "${env:GLEAN_MCP_URL}"
}
```

If your Configurator emits **`headers`** (e.g. API token fallback) or a different **`type`**, prefer the **generated JSON** from Glean over this minimal example.

**Not using Glean:** Remove the **`Glean`** block from **`mcpServers`** in `.cursor/mcp.json`. All personas work without it.

**Requirements:**

- **Glean** tenant with MCP enabled by your admin ([Setting up Glean MCP server](https://docs.glean.com/administration/platform/mcp/enable-mcp-servers)).
- **OAuth** via Glean’s authorization server where enabled, or **Glean API token** with required scopes when OAuth is unavailable ([Authentication](https://docs.glean.com/administration/platform/mcp/about#authentication)) — **no tokens in git**; use **`${env:…}`** per [`cursor-mcp.md`](cursor-mcp.md).
- **Node.js ≥ 18** if you use any **npx**-based MCP helpers (optional; not required for the default HTTP entry).

## `.cursor/settings.json` policy

Same as other MCP docs: repo may track a **minimal** `.cursor/settings.json`; **never** commit secrets. User-specific overrides stay local.

## Preferred path: Configurator + Cursor

1. Open **[MCP Configurator](https://app.glean.com/settings/install?mcpConfigure=true&mcpHost=cursor)** (or **Profile → Settings → Install → MCP Configurator** in Glean).
2. Select **Cursor**, copy the **URL** (and headers if shown), set **`GLEAN_MCP_URL`** (or paste into `mcp.json` per org policy).
3. Optionally install the **Glean** plugin from the Cursor **marketplace** for UX; MCP connection remains the source of tools.
4. In Cursor, complete **OAuth** or token flow under **Settings → MCP**.

## Reference docs

| Doc | Purpose |
|-----|---------|
| [cursor-mcp.md](cursor-mcp.md) | MCP transports, `${env:…}`, AskQuestion / Agent mode |
| [atlassian-cursor-workflow.md](atlassian-cursor-workflow.md) | Optional Jira/Confluence read (overlap with indexed content—see conventions below) |
| [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) | GitLab MR flow (optional MCP; no autonomous writes) |

## Search-source conventions (summary)

- **Local codebase** (`Read`, `Grep`, `SemanticSearch`): source of truth for **this repo’s** implementation and file state.
- **Glean:** broad **“what does the org know?”** discovery across connected systems; **permission-aware**; good for prior art, runbooks, incidents, policies **not** only in one repo.
- **Atlassian MCP:** **targeted** Jira issue fetch or Confluence space search when you have a **key** or **space**; avoid duplicate heavy queries if Glean already answered the same question.
- **Never assume** any optional MCP is loaded; degrade gracefully.

## Agent reference pattern

- **Do:** Use Glean MCP tools for **read** search / document retrieval when the task benefits from **institutional** context.
- **Do not:** Assume Glean is configured; **do not** perform **writes** to Glean or indexed sources from automated agent runs under this workspace policy.

### Typical tool names (verify in Cursor after connect)

Glean’s MCP exposes tools such as **search**, **chat**, and **read_document** (names may vary by server version—check **Settings → MCP** for the live list). Prefer explicit prompts: e.g. “search Glean for …”, “read document …”.

## Troubleshooting

| Symptom | What to check |
|--------|----------------|
| No Glean tools under **Settings → MCP** | Restart Cursor; confirm **`Glean`** (or a name matching `glean`) exists in `.cursor/mcp.json`. |
| Connection errors / invalid URL | **`GLEAN_MCP_URL`** unset or wrong—re-copy from **MCP Configurator**; URL is **tenant-specific**. |
| OAuth fails | Browser popup, SSO, ad blockers; Glean admin [MCP / OAuth](https://docs.glean.com/administration/oauth/authorization-server.md) settings. |
| “No data” or empty results | Query too broad; or your user lacks access to that content in Glean (permissions follow identity). |
| Overlap with Atlassian results | Normal; use **Atlassian** for ticket-key or space-targeted reads; use **Glean** for cross-system discovery—avoid redundant back-to-back queries. |

## Manual verification checklist

Use this after editing `.cursor/mcp.json` or onboarding a new machine (no CI automation required).

- [ ] `.cursor/mcp.json` parses (`python3 -m json.tool .cursor/mcp.json`).
- [ ] Cursor **Settings → MCP** lists **Glean** (if configured) and shows **connected** / tools after auth.
- [ ] **Sample search:** Ask the agent to **search Glean** for a known internal topic you can access.
- [ ] **Policy:** Confirm **no** workflow **required** Glean for core **`/plan`**, **`/fix`**, **`/qa`**, or **`/run`** steps when Glean was disabled.

## Limitations (high level)

- **MCP/tool availability** varies by Cursor version and tenant; skills and agents must not **require** Glean.
- **Read-only** in this workspace; mutating Glean or connected systems via MCP is out of scope.
- **Plugin vs. raw MCP:** Some tenants use **marketplace plugin only**; others use **Configurator-generated JSON** alone—both are valid if tools appear and authenticate.
