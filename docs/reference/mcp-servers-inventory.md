# MCP servers inventory

Optional MCP servers used with this workspace. **GitLab** is a local **stdio** process (`@zereight/mcp-gitlab`) in **user-global** `~/.cursor/mcp.json`. Atlassian and Glean are typically **Streamable HTTP**. Tool names match Cursor descriptors when the IDE has loaded the server (`~/.cursor/projects/<project>/mcps/<server>/tools/*.json`). **Verify live tools** in **Settings → Tools & MCP** after upgrades — lists can drift.

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
| Transports, `${env:…}`, config | [cursor-mcp.md](cursor-mcp.md) |

---

## GitLab

| | |
|--|--|
| **`mcp.json` key** | `GitLab` (Cursor namespace `user-GitLab`) |
| **Transport** | **stdio** — `@zereight/mcp-gitlab` |
| **API** | `GITLAB_API_URL` = `${env:GITLAB_API_URL}` (e.g. `https://gitlab.example.com/api/v4`) |
| **Auth** | `${env:GITLAB_PERSONAL_ACCESS_TOKEN}` — never commit the PAT |
| **Config path** | `~/.cursor/mcp.json` (not a committed HTTP `gitlab.com` / native `/api/v4/mcp` entry) |
| **Typical use** | Project / MR / issue metadata; MR create/update only after explicit Finish confirmation. |

**Do not install** the Cursor marketplace **GitLab** plugin (OAuth to gitlab.com) when using a self-managed GitLab instance prior to **18.3+** without native `/api/v4/mcp`.

**Tools:** depend on the zereight server version (e.g. `health_check`, `whoami`, `get_project`, `search_repositories`, `list_merge_requests`, `get_merge_request`, approval/protection reads, plus write tools when not in read-only mode). Verify in **Settings → Tools & MCP**.

**Read vs write:** The package can mutate GitLab. **`/run` orchestrator policy:** no MR/API writes without explicit user confirmation — see [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) and **`.cursor/rules/git-gitlab-mutations.mdc`**.

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
| **URL (committed)** | `https://example-org.glean.com/mcp/default` |
| **Typical use** | Org-wide enterprise search and document read; optional `chat` for synthesis. |

**Tools (from descriptors):** `chat`, `read_document`, `search`

**Read vs write:** **Read / query** from the product perspective (search, fetch document content, conversational answers). Does not replace local repo tools for **this** repository’s files; see [glean-cursor-workflow.md](glean-cursor-workflow.md).

---

