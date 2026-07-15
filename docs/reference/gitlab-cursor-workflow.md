# GitLab workflow with Cursor (human-in-the-loop)

This workspace **ships through GitLab** merge requests. Agents **document** and **generate text**; **you** run git, IDE commands, or CLI tools after explicit confirmation at each step. See also **`docs/reference/cursor-plugins.md`** for plugin packaging and marketplace mechanics.

## Project-level GitLab MCP (`.cursor/mcp.json`)

The repo includes a **GitLab MCP** entry using the **official HTTP transport** from [GitLab’s MCP documentation](https://docs.gitlab.com/user/gitlab_duo/model_context_protocol/mcp_server/):

```json
"GitLab": {
  "type": "http",
  "url": "https://gitlab.com/api/v4/mcp"
}
```

**Why it was not present in the first ROAD-24 pass:** early implementation avoided committing MCP entries so clones without **GitLab Duo** (Premium/Ultimate — MCP is beta) would not see a half-configured integration. The team chose to **ship the canonical URL** so the project declares the intended integration; adjust or remove as below.

**Requirements (GitLab.com):**

- [GitLab Duo](https://docs.gitlab.com/user/duo_agent_platform/turn_on_off/) and beta/experimental features enabled on the group or instance.
- First connect: Cursor opens **OAuth** in the browser — **no tokens in the repo**.

**Self-managed GitLab:** replace the host in **`url`** with your instance, e.g. `https://gitlab.example.com/api/v4/mcp`, or use **`"url": "${env:GITLAB_MCP_URL}"`** so the committed file stays free of internal hostnames (**[cursor-mcp.md](cursor-mcp.md)** — config interpolation).

**Not using GitLab MCP:** delete the **`GitLab`** block from **`mcpServers`** in `.cursor/mcp.json` (or clear **`mcpServers`** to `{}`). Your clone may already use a **custom** URL locally — that is fine; do not commit secrets.

## Preferred path: Cursor GitLab integration

1. **Install** the **GitLab**-verified plugin from the Cursor **marketplace** (browse from the editor’s Extensions/Marketplace panel or [cursor.com/marketplace](https://cursor.com/marketplace)). The upstream source is commonly published as **`cursor-gitlab-plugin`** on GitHub; use the marketplace entry as the supported install path so updates track the editor.
2. **Configure** the **GitLab MCP server** — project entry is in **`.cursor/mcp.json`** (above); complete OAuth when Cursor prompts. The marketplace plugin may bundle or complement the same GitLab MCP endpoint; follow Cursor **Settings → Tools & MCP** for connection status.
3. After you have **locally committed** changes you approve, use plugin or MCP commands such as **`create-merge-request`** (exact naming may vary by plugin version) to open the MR flow from the current branch. The agent **does not** click the UI for you.

Agents reference this flow in **`run-pipeline`** Finish: they suggest steps; **you** execute.

## Reference docs

| Doc | Purpose |
|-----|---------|
| [cursor-plugins.md](cursor-plugins.md) | Plugin layout, local testing, team marketplaces |
| [cursor-mcp.md](cursor-mcp.md) | MCP transports and configuration |

## Human-in-the-loop MR flow (summary)

1. Complete **`/run`** through **`/summary`** (or your team’s gates).
2. Respond to **Finish** prompts: commit message suggestions → push confirmation → MR target branch confirmation.
3. Run **`git commit`** / **`git push`** yourself (or via IDE) after confirming.
4. Create the MR with the **plugin**, or paste output from **`scripts/tools/mr-description-from-spec.sh`** into the GitLab UI, or use **`glab`** (below).

## Optional: `glab` CLI (scriptable fallback)

Use when you prefer the terminal. **Do not** commit tokens. Pass tokens via env (e.g. **`GITLAB_TOKEN`**) or `glab` auth for your session only.

**Non-interactive-style placeholders** (fill in before running):

```bash
# Example only — adjust project, branches, and labels to your repo
export GITLAB_TOKEN="***"   # set in your shell; never commit
glab mr create \
  --title "ROAD-24: GitLab integration" \
  --description "$(./scripts/tools/mr-description-from-spec.sh docs/specs/YYYY-MM-DD-slug-spec.md)" \
  --target-branch main \
  --label dev --label sre
```

Remove or change `--label` flags to match **your** project’s label set. Domain tags in specs map to labels as: **`[dev]` → `dev`**, **`[sre]` → `sre`**, **`[data]` → `data`** (see **`run-pipeline`** skill and MR generator output).

## Agent reference pattern

- **Do:** Link to this doc, emit MR title/body text, suggest `glab` lines with placeholders.
- **Do not:** Invoke mutating GitLab APIs or `glab mr create` autonomously from orchestration; **do not** store credentials in the repo.

## Limitations (high level)

- **MCP / plugin availability** varies by machine and Cursor version; skills must not assume GitLab MCP tools exist in every session.
- **GitLab tier and instance settings** (required approvals, protected branches, MR rules) affect what you can do in the UI or API — not controlled by this workspace.
- **Forum / feature gaps** vs other hosts (e.g. GitHub) change over time; prefer official GitLab and Cursor docs for authoritative behavior.
