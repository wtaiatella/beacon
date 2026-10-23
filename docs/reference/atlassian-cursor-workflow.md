# Atlassian workflow with Cursor (read-only slice) — ROAD-01 Phase 1

This workspace uses **read-only** **Jira** and **Confluence** context when the **Atlassian Rovo MCP** integration is installed and authenticated. Agents **do not** create issues, post comments, transition work items, or edit Confluence pages from this repo’s Phase 1 guidance—those belong to **ROAD-01 Phase 2** and **ROAD-12** (`/run --sync`). The same **human-in-the-loop** boundaries as [GitLab workflow](gitlab-cursor-workflow.md) and **`.cursor/rules/git-gitlab-mutations.mdc`** apply to **git and GitLab**; this document adds **Atlassian read** expectations only.

## Project-level Atlassian MCP (`.cursor/mcp.json`)

The repo includes an **Atlassian Rovo MCP** entry pointing at Atlassian’s hosted MCP endpoint (see [Setting up IDEs — Atlassian Rovo MCP Server](https://support.atlassian.com/rovo/docs/setting-up-ides/)):

```json
"Atlassian-MCP-Server": {
  "type": "http",
  "url": "https://mcp.atlassian.com/v1/mcp"
}
```

**Why `type` + `url`:** Aligns with the **GitLab** HTTP MCP pattern in the same file and with Atlassian’s VS Code MCP examples. Cursor’s UI may show a slightly shorter block; if connection fails, confirm **`https://mcp.atlassian.com/v1/mcp`** (after **30 June 2026**, **`/v1/sse`** is not supported—migrate to **`/mcp`**).

**Older Cursor builds** may need the **stdio proxy** instead (from Atlassian’s docs):

```json
"Atlassian-Rovo-MCP": {
  "command": "npx",
  "args": ["-y", "mcp-remote@latest", "https://mcp.atlassian.com/v1/mcp"]
}
```

Prefer the **HTTP** form when your Cursor version supports it.

**Requirements:**

- **Atlassian Cloud** site with **Jira** and/or **Confluence** (and access for your user).
- **OAuth 2.1** in the browser on first connect, or **API token** if your org [enables token auth for Rovo MCP](https://support.atlassian.com/security-and-access-policies/docs/control-atlassian-rovo-mcp-server-settings/) — **no tokens in git**; use env-based patterns per [`cursor-mcp.md`](cursor-mcp.md).
- **npx / Node ≥ 18** if you use the **`mcp-remote`** fallback.

**Not using Atlassian MCP:** Remove the **`Atlassian-MCP-Server`** (or **`Atlassian-Rovo-MCP`**) block from **`mcpServers`** in `.cursor/mcp.json`. All personas work without it.

## `.cursor/settings.json` policy

The repo **whitelists** `.cursor/settings.json` in `.gitignore` so teams **may** commit **non-secret** workspace defaults. This checkout includes a **minimal** tracked file (`{}`) so the path exists and merges cleanly; add only **safe, shared** Cursor/VS Code settings your team agrees on. **User-specific** overrides (experimental flags, local paths) should live in **user** settings or untracked local edits—**never** commit API tokens, OAuth secrets, or host-specific credentials.

## Preferred path: Cursor + Atlassian integration

1. **Install** the **Atlassian** integration from the Cursor **marketplace** when available ([cursor.com/marketplace](https://cursor.com/marketplace)), or follow **Settings → Tools & MCP** to add the server using the URL above.
2. **Complete authentication** when Cursor prompts (browser OAuth or org-approved token flow).
3. **Read-only workspace policy (Phase 1):** Use MCP tools only to **fetch** issues, **search** Jira, and **read/search** Confluence. Do **not** use agent sessions to create or mutate Atlassian content; that is out of scope until Phase 2.

Atlassian’s own docs list example actions that **write** (e.g. create a page). Your **permissions** still apply—this workspace’s **agent instructions** defer **writes** to a future **`/sync`** design; ignore write-suggesting examples for automated agent runs until Phase 2 is specified.

## Reference docs

| Doc | Purpose |
|-----|---------|
| [cursor-mcp.md](cursor-mcp.md) | MCP transports, `${env:…}`, **AskQuestion** / Agent mode |
| [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) | GitLab MR flow (parity: optional MCP, no autonomous remote writes) |

## Human-in-the-loop (summary)

1. **Configure** MCP in `.cursor/mcp.json` and authenticate in Cursor.
2. For **pipeline Finish** (commit / push / MR), follow **`run-pipeline`** and `scripts/tools/mr-description-from-spec.sh` — **you** confirm each mutating **git/GitLab** step.
3. **AskQuestion / Agent mode:** Structured Finish prompts may be **unreliable** in Agent mode; orchestrators should **fall back to numbered chat prompts** — see **AskQuestion** in [`cursor-mcp.md`](cursor-mcp.md).

## Agent reference pattern

- **Do:** Use Atlassian MCP tools for **read** context (issue by key, Jira search, Confluence search) when the user’s task benefits from it.
- **Do not:** Assume MCP is configured; **do not** perform Jira/Confluence **writes** under Phase 1 guidance; **do not** put credentials in the repo.

## Troubleshooting

| Symptom | What to check |
|--------|----------------|
| No Atlassian tools under **Settings → MCP** | Restart Cursor; confirm JSON in `.cursor/mcp.json`; try **`mcp-remote`** fallback on older Cursor. |
| OAuth fails | Browser popup, ad blockers, org SSO; Atlassian admin [Rovo MCP settings](https://support.atlassian.com/security-and-access-policies/docs/control-atlassian-rovo-mcp-server-settings/). |
| “No data” for an issue | Issue key wrong, or your user lacks **Browse** on that project; MCP uses **your** identity. |
| Fetch/search fails or errors | **Unauthenticated** or **blocked** MCP session—operations **fail** or return nothing; fix auth before relying on agents. |

## Manual verification checklist

Use this after editing `.cursor/mcp.json` or onboarding a new machine (no CI automation required).

- [ ] `.cursor/mcp.json` parses (`python3 -m json.tool .cursor/mcp.json`).
- [ ] Cursor **Settings → MCP** lists the Atlassian server and shows **connected** / tools after OAuth (or token, per org policy).
- [ ] **Sample Jira read:** Ask the agent to fetch a **known issue key** (e.g. `PROJ-123`) and confirm fields return.
- [ ] **Sample Confluence read:** Ask the agent to **search** a space or page title you can access.
- [ ] **Phase 1 policy:** Confirm you did **not** rely on agent-driven **create/update** flows for Jira or Confluence in automation (writes remain out of scope).

## Limitations (high level)

- **MCP/tool availability** varies by Cursor version and org; skills must not assume Atlassian tools exist every session.
- **Read-only Phase 1** is a **documentation and agent-behavior** slice; the underlying Atlassian MCP may expose write-capable tools—workspace policy defers using them to **ROAD-01 Phase 2**.
