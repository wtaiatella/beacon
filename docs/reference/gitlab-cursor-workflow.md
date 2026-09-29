# GitLab workflow with Cursor (human-in-the-loop)

This workspace **ships through GitLab** merge requests. Agents **document** and **generate text**; **you** confirm commit, push, and MR steps. See also **`docs/reference/cursor-plugins.md`** for plugin packaging (unrelated to GitLab MCP).

## Supported GitLab MCP (`@zereight/mcp-gitlab`)

Avalara SCM is **GitLab 17.5**. The **native** GitLab HTTP MCP (`/api/v4/mcp`) requires **18.3+**. The **Cursor marketplace GitLab plugin** OAuths to **gitlab.com** by default and must **not** be installed — it fights the working server.

Use the **stdio** server **`@zereight/mcp-gitlab`** against the SCM REST API.

**Live config (Cursor):** `~/.cursor/mcp.json` (user-global). Do **not** put PATs in git.

```json
"GitLab": {
  "command": "npx",
  "args": ["-y", "@zereight/mcp-gitlab"],
  "env": {
    "GITLAB_PERSONAL_ACCESS_TOKEN": "${env:GITLAB_PERSONAL_ACCESS_TOKEN}",
    "GITLAB_API_URL": "https://scm.platform.us-west-2.avalara.io/api/v4",
    "GITLAB_READ_ONLY_MODE": "false",
    "USE_GITLAB_WIKI": "false",
    "USE_MILESTONE": "false",
    "USE_PIPELINE": "false"
  }
}
```

**Requirements:**

- Env var **`GITLAB_PERSONAL_ACCESS_TOKEN`** (PAT on SCM with `api` scope as needed). Cursor interpolates `${env:…}` — no token in the JSON file.
- **`GITLAB_API_URL`** must include **`/api/v4`** (API root, not the web UI host alone).
- Node on `PATH` (or an absolute `command` / `PATH` in `env`, as on some nvm setups).

**Do not:**

- Install the Cursor **GitLab** marketplace plugin.
- Point MCP at `https://gitlab.com/api/v4/mcp` or `https://scm…/api/v4/mcp` (native MCP is not on this instance).
- Commit tokens or OAuth client secrets.

**Not using GitLab MCP:** omit the **`GitLab`** block from `~/.cursor/mcp.json`. Personas degrade gracefully.

After a config change: **Settings → Tools & MCP**, confirm a single **GitLab** / `user-GitLab` server (no `plugin-gitlab-GitLab`). Smoke test: `health_check` then `whoami` — URL must be the SCM API, user your Avalara account.

## Human-in-the-loop MR flow (summary)

1. Complete **`/run`** through **`/summary`** (or your team’s gates).
2. Respond to **Finish** prompts: commit message → push confirmation → MR target branch.
3. Run **`git commit`** / **`git push`** only as Finish / git rules allow after you confirm.
4. After explicit MR confirmation, the orchestrator may create/update the MR **via GitLab MCP** (`mcp__GitLab__*` / `user-GitLab`), presenting title/body first. Paste output from **`scripts/tools/mr-description-from-spec.sh`** if you create the MR in the UI instead.

Agents reference this flow in **`run-pipeline`** Finish: they suggest steps; mutating GitLab stays behind confirmation.

## Reference docs

| Doc | Purpose |
|-----|---------|
| [cursor-mcp.md](cursor-mcp.md) | MCP transports and configuration |
| [mcp-servers-inventory.md](mcp-servers-inventory.md) | Server keys and typical tools |

## Optional: `glab` CLI

This workspace is **not** authenticated for `glab`; do not treat it as the default path. If you use it locally, pass tokens via env only — **never** commit them.

## Agent reference pattern

- **Do:** Link to this doc, emit MR title/body text, use GitLab MCP after confirmation.
- **Do not:** Invoke mutating GitLab APIs or `glab mr create` autonomously from orchestration; **do not** store credentials in the repo.

## Limitations (high level)

- **MCP availability** varies by machine; skills must not assume GitLab tools exist in every session.
- **GitLab instance settings** (approvals, protected branches) are not controlled by this workspace.
- Native GitLab MCP / Duo HTTP MCP is **out of scope** until SCM is on a version that exposes `/api/v4/mcp`.
