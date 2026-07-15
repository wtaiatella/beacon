# MCP servers inventory (`.cursor/mcp.json`)

This workspace registers four **Streamable HTTP** MCP servers in **`.cursor/mcp.json`**. Tool names below match **Cursor MCP tool descriptors** under the user’s **`mcps/`** tree when the IDE has loaded the server (path pattern: `~/.cursor/projects/<project>/mcps/<server>/tools/*.json`). **Verify live tools** in **Settings → MCP** after upgrades — lists can drift.

## Read vs write and `Task(readonly)`

| Concept | Meaning |
|--------|---------|
| **Server tool classification** | Whether a given MCP tool is designed for **read** (query, fetch) or **write** (create/update/transition) on the remote system. |
| **`readonly` on `Task()`** | Cursor may restrict **file edits and state-changing shell** for the subagent — it does **not** guarantee MCP servers refuse writes. **Behavioral read-only** for external systems is enforced by **agent instructions** (e.g. **`mcp-*`** agents, **`00-workspace-router.mdc`**, workflow docs). |
| **Orchestrator GitLab API** | The **`/run`** main agent does **not** perform mutating GitLab API calls; see **`.cursor/rules/git-gitlab-mutations.mdc`** and **`.cursor/skills/run-pipeline/SKILL.md`** § 9. |

## Cross-links

| Integration | Primary workflow doc |
|-------------|----------------------|
| GitLab | [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) |
| Atlassian (Jira / Confluence) | [atlassian-cursor-workflow.md](atlassian-cursor-workflow.md) |
| Glean | [glean-cursor-workflow.md](glean-cursor-workflow.md) |
| AvaTax Release Central (ARC) | [arc-mcp-workflow.md](arc-mcp-workflow.md) |
| Transports, `${env:…}`, config | [cursor-mcp.md](cursor-mcp.md) |

---

## GitLab

| | |
|--|--|
| **`mcp.json` key** | `GitLab` |
| **URL (committed)** | `https://gitlab-mcp-service.gamma.dev.us-west-2.aws.avalara.io/mcp` |
| **Typical use** | Read-only project / MR metadata for planning and triage. |

**Tools (from descriptors):** `get_branch_protection`, `get_merge_request_approval_rules`, `get_project`, `get_protected_environments`

**Read vs write:** Listed tools are **read** (fetch configuration and metadata). Workspace policy: **read-only usage** — no MR create/update or other mutating GitLab API from agents orchestrating **`/run`**; see [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md).

---

## Atlassian-MCP-Server

| | |
|--|--|
| **`mcp.json` key** | `Atlassian-MCP-Server` |
| **URL (committed)** | `https://mcp.atlassian.com/v1/mcp` |
| **Typical use** | Jira issue fetch/search, Confluence page read/search; optional writes if your workflow explicitly allows them. |

**Tools (from descriptors):**

- **Read-oriented:** `atlassianUserInfo`, `fetchAtlassian`, `getAccessibleAtlassianResources`, `searchAtlassian`, `getConfluencePage`, `getConfluencePageDescendants`, `getConfluencePageFooterComments`, `getConfluencePageInlineComments`, `getConfluenceCommentChildren`, `getPagesInConfluenceSpace`, `getConfluenceSpaces`, `searchConfluenceUsingCql`, `getIssueLinkTypes`, `getJiraIssue`, `getJiraIssueRemoteIssueLinks`, `getJiraIssueTypeMetaWithFields`, `getJiraProjectIssueTypesMetadata`, `getTransitionsForJiraIssue`, `getVisibleJiraProjects`, `lookupJiraAccountId`, `searchJiraIssuesUsingJql`
- **Write / mutating (Jira / Confluence):** `addCommentToJiraIssue`, `addWorklogToJiraIssue`, `createIssueLink`, `createJiraIssue`, `editJiraIssue`, `transitionJiraIssue`, `createConfluenceFooterComment`, `createConfluenceInlineComment`, `createConfluencePage`, `updateConfluencePage`

**Read vs write:** The server exposes **both** retrieval and mutation tools. **This workspace’s read-only onboarding** emphasizes search/fetch — see [atlassian-cursor-workflow.md](atlassian-cursor-workflow.md). Use write tools only when the user and policy expect mutating actions.

---

## glean_default

| | |
|--|--|
| **`mcp.json` key** | `glean_default` |
| **URL (committed)** | `https://avalara-prod-be.glean.com/mcp/default` |
| **Typical use** | Org-wide enterprise search and document read; optional `chat` for synthesis. |

**Tools (from descriptors):** `chat`, `read_document`, `search`

**Read vs write:** **Read / query** from the product perspective (search, fetch document content, conversational answers). Does not replace local repo tools for **this** repository’s files; see [glean-cursor-workflow.md](glean-cursor-workflow.md).

---

## avatax-release-central

| | |
|--|--|
| **`mcp.json` key** | `avatax-release-central` |
| **URL (committed)** | `https://avatax-release-central.gamma.int.us-west-2.aws.avalara.io/api/kb/mcp/` |
| **Auth** | Optional `Authorization: Bearer ${env:ARC_MCP_TOKEN}` — see [arc-mcp-workflow.md](arc-mcp-workflow.md) |

**Tools (from descriptors):**

- **Core search:** `search_arc_knowledge`, `search_avatax_knowledge`, `search_database_schema`, `search_federated`, `search_release_context`
- **Release context:** `get_release_context`, `list_releases`
- **Project groups:** `search_proj_content`, `search_proj_cross_border`, `search_proj_ecosystem`, `search_proj_hub`, `search_proj_shared_libs`, `search_proj_soap_batch`, `search_proj_tcs`, `search_proj_tcs_deps`, `search_proj_testing`, `search_proj_tss`
- **Feature-scoped:** `search_feat_*` (many tools, e.g. `search_feat_vat`, `search_feat_nexus`, `search_feat_cross_border`, … — verify full set in **Settings → MCP**)

**Read vs write:** **Read-only** retrieval against Release Central indexes — agents do not mutate RC content from this repo’s guidance; see [arc-mcp-workflow.md](arc-mcp-workflow.md).

---

## Pre-plan vs in-session (ARC)

For **`/run`**, the orchestrator may delegate **`Task(mcp-arc)`** during **Pre-plan context** when triage requires ARC — **in addition to** in-session ARC tool use by **`/plan`**, **`/dev`**, and **`/fix`**. See [arc-mcp-workflow.md](arc-mcp-workflow.md) (**Two lanes**) and **`docs/run-pipeline-reference.md`**.
