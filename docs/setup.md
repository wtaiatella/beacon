# Agentic Workspace — Setup Guide

## Prerequisites

- **Node.js >= 18** — Required for hook scripts (`node -e` for JSON parsing) and future MCP servers. Install from [https://nodejs.org/](https://nodejs.org/).
- **git >= 2.x** — For cloning this workspace and target application repos.
- **Cursor IDE or CLI** — This workspace is designed for Cursor (IDE or CLI). Download from [https://cursor.com](https://cursor.com).

## Fetch and install from a GitLab Release (tarball)

If you prefer **not** to `git clone` the full history, you can install the packaged workspace from a **GitLab Release** asset named **`agentic-workspace-*.tar.gz`** (for example **`agentic-workspace-26.4.1.tar.gz`**, matching the release tag). That archive contains the same tree you would use after a clone—without a **`.git`** directory—so it is a good fit for adopters who only need the workspace files.

A tarball install stays a plain directory tree with **no** **`.git`** metadata, so **`scripts/upgrade.sh`** (which pulls from **git** remotes) does not apply there. To refresh, download and extract a **newer** release tarball, or **`git clone`** the repository if you want ongoing upgrades via **`upgrade.sh`**.

**Find a release:** Open the project’s **Releases** page in the browser, for example [https://scm.platform.avalara.io/avatax-platform/agentic-workspace/-/releases](https://scm.platform.avalara.io/avatax-platform/agentic-workspace/-/releases). The latest release is listed at the top; open any release to download its assets. Pick the tarball whose version in the filename matches the tag you want.

**Download and extract:** Prefer a **new, empty directory** as the destination so you do not overwrite unrelated files. Extracting on top of an **existing** checkout or another project’s root can replace files in place—only do that if you intend to refresh that tree with the release contents.

On the release you chose, use **Download** on the **`agentic-workspace-*.tar.gz`** asset, or copy that asset’s **direct link** and fetch it from a shell. GitLab generates the download URL per asset; using the link from the UI avoids guessing paths.

```bash
mkdir -p ~/work && cd ~/work
curl -fL -O "<paste-the-direct-download-URL-for-the-tarball-from-the-Release-page>"
tar -xzf agentic-workspace-*.tar.gz
cd agentic-workspace-*/
```

The published archive has a **single top-level directory** named **`agentic-workspace-<VERSION>/`** (see the bundle layout in **`scripts/tools/build-release-bundle.sh`**). **`cd`** into that folder so **`scripts/setup.sh`** is at the repository root.

Alternatively, download the **`.tar.gz`** in the browser, move it to an empty parent directory, and run **`tar -xzf`** on the file, then **`cd`** into **`agentic-workspace-*/`** as above.

**After extract:** From that workspace root (the directory that contains **`scripts/setup.sh`**), run **`./scripts/setup.sh`** as in [Step 1: Clone and Setup](#step-1-clone-and-setup) below. The script performs the same validation and setup whether you arrived via clone or tarball.

## Step 1: Clone and Setup

If you already unpacked a **release tarball**, skip **`git clone`** and start at **`./scripts/setup.sh`** (see [Fetch and install from a GitLab Release (tarball)](#fetch-and-install-from-a-gitlab-release-tarball)).

```bash
git clone <repo-url> && cd agentic-workspace
./scripts/setup.sh   # validates environment, makes scripts executable, checks integrity
```

The setup script will:
- Check prerequisites (Node.js >= 18, git, Cursor)
- Make all hook and tool scripts executable
- Create runtime directories (`docs/specs/`, `docs/summaries/`, `docs/sessions/`)
- Validate workspace integrity (agents, skills, hooks, tool scripts, JSON validity — all relationship-based, no hardcoded counts)
- Print next steps

### `.env.local` (orchestrator root)

Optional **gitignored** file at the repository root for machine-local settings. It is **not** tracked (`*` + whitelist in `.gitignore`; `/.env.local` is listed explicitly for clarity).

| Key | Purpose |
|-----|---------|
| `PROJECTS_ROOT` | Absolute path to a directory whose **immediate subdirectories** are candidate target repositories for **`scripts/tools/attach-project.sh`** (ROAD-48). |

On first use, **`attach-project.sh`** can prompt for this path and persist `PROJECTS_ROOT=…` into `.env.local` (sourced as shell; the script writes shell-quoted values when persisting paths with spaces).

**Branch / clone drift:** Your local **`development`** (or other) branch may be **ahead of** **`origin/development`** after local commits — documentation for **`/run`**, **`--manual`**, and **MCP** still applies; rebase or push when your team’s workflow requires it.

## Step 2: Configure MCP Servers (Optional)

The committed **`.cursor/mcp.json`** is a **team baseline** (often GitLab + optional Atlassian + optional Glean). Your checkout may have **local, uncommitted edits** (different **`url`**, extra blocks, or **`${env:…}`** placeholders) — that is normal; **do not commit** tokens or secrets. Prefer **environment-variable interpolation** for tenant-specific URLs — see **[docs/reference/cursor-mcp.md](reference/cursor-mcp.md)**.

The committed baseline may use an **org-managed GitLab MCP** URL (not necessarily **gitlab.com**). For the **official GitLab.com** HTTP MCP pattern, see [GitLab MCP server](https://docs.gitlab.com/user/gitlab_duo/model_context_protocol/mcp_server/) (often **GitLab Duo** + OAuth on first use). If your team uses a different host, replace the **`GitLab`** block or set **`url`** to your self-managed instance or **`${env:GITLAB_MCP_URL}`** when your team standardizes on that.

### Atlassian (Jira + Confluence, optional)

For **read-only** issue fetch and Confluence search, add or keep the **Atlassian Rovo MCP** entry (see [Atlassian — setting up IDEs](https://support.atlassian.com/rovo/docs/setting-up-ides/)). The repo declares **`Atlassian-MCP-Server`** → `https://mcp.atlassian.com/v1/mcp` in `.cursor/mcp.json`; complete **OAuth** (or org-approved API token) in Cursor on first use. **Without** a configured, authenticated session, Jira/Confluence tools **fail** or return no data.

Workspace **Phase 1** uses Atlassian context for **read** only; Jira/Confluence **writes** are out of scope until **ROAD-01 Phase 2**. Full steps, fallbacks for older Cursor, and a **manual verification checklist** are in **[docs/reference/atlassian-cursor-workflow.md](reference/atlassian-cursor-workflow.md)**.

### Glean (enterprise search, optional)

**Strongly recommended** for teams with Glean when you want **organization-wide** context (design docs, Slack, wikis, incidents) alongside this repo’s code. **Not required** for any core workflow—`/plan`, `/fix`, `/qa`, and `/run` work fully without it.

The repo may declare a **`Glean`** server in `.cursor/mcp.json` using a **tenant-specific** URL from Glean’s **MCP Configurator** (often via **`${env:GLEAN_MCP_URL}`**—see **[docs/reference/cursor-mcp.md](reference/cursor-mcp.md)**). Complete **OAuth** or API token setup in Cursor (**Settings → MCP**). You may also install the **Glean** plugin from the Cursor **marketplace**; it still depends on a valid MCP connection. Full steps, troubleshooting, and removal instructions: **[docs/reference/glean-cursor-workflow.md](reference/glean-cursor-workflow.md)**.

### Other marketplace MCPs (e.g. Context7)

Optional servers such as **[Context7](https://context7.com/)** (library docs) or team-specific MCPs can be added the same way—see **[docs/reference/cursor-mcp.md](reference/cursor-mcp.md)** for transports and **`${env:…}`** patterns. None are required for core flows.

All persona subagents are fully functional using Cursor built-in tools and custom scripts without MCP; MCP is an optional enhancement layer.

To add **additional** company MCP servers, edit `.cursor/mcp.json` with one of three patterns:

- **npx** (published to npm): `"command": "npx", "args": ["-y", "@your-org/mcp-server"]`
- **Local build:** `"command": "node", "args": ["/path/to/build/index.js"]`
- **Docker:** `"command": "docker", "args": ["run", "-i", "your-org/mcp-server"]`

After adding, restart Cursor and verify under **Settings > MCP**.

**Verification (after any `mcp.json` or `settings.json` edit):** run **`./scripts/setup.sh`** — it **JSON-parses** `.cursor/mcp.json`, `.cursor/hooks.json`, and `.cursor/settings.json` (when present). Then open Cursor **Settings → MCP** and confirm servers connect. For Atlassian, follow the **manual verification checklist** in **[atlassian-cursor-workflow.md](reference/atlassian-cursor-workflow.md)** (tools list, sample Jira key, sample Confluence search).

## Step 3: Verify Rule, Subagents, and Hooks

Open the workspace in Cursor and verify:

- **Settings > Rules** — 1 rule shows as **Always Apply** (`00-workspace-router`)
- **`.cursor/agents/`** — subagents are present with valid frontmatter (run `setup.sh` for exact count)
- **Settings > Hooks** — 7 hooks registered:
  - `beforeShellExecution` — blocks dangerous commands
  - `beforeReadFile` — blocks reading secrets files
  - `subagentStart` — blocks write-capable agents on protected branches
  - `afterFileEdit` — auto-formats with project formatter
  - `sessionStart` — injects spec status and session memory
  - `sessionEnd` — audit log + post-session verification (2 hooks)
- **Test:** type `/plan myapp/ "test"` (manual mode) or `/run myapp/ "test"` (automated mode) and verify the agents activate

## Step 4: Clone Target Repos

```bash
git clone <your-app-repo> myapp/
```

Confirm gitignored: `git status` should not show child repos.

### Multi-root attach (ROAD-48)

**Pointer:** Use **`./scripts/tools/attach-project.sh`** to pair this orchestrator repo with one writable target under **`PROJECTS_ROOT`**, write **`docs/sessions/<active-session-id>/session.code-workspace`**, and open Cursor in multi-root mode. Architecture, trace anchors (`PROJECT_HASH`), and pipeline behavior are defined in **[ROAD-48 — Dynamic multi-root project attachment](specs/2026-04-11-road-48-dynamic-multi-root-project-attachment-workspace-generation-spec.md)**.

To bind the orchestrator repo (read-only context) and an external clone (writable execution) in one Cursor window, run:

```bash
./scripts/tools/attach-project.sh
```

The script reads **`PROJECTS_ROOT`** from **`.env.local`**, lets you **`select`** an immediate subdirectory, writes **`docs/sessions/<active-session-id>/session.code-workspace`**, and opens it with the **`cursor`** CLI. Session id uses **`docs/sessions/ACTIVE_SESSION`** when that directory exists; otherwise it runs **`session-memory.sh begin-run attach`**. See **`attach-project.sh --help`** for the exact order.

Use **`attach-project.sh --no-cursor`** to only generate the workspace file.

#### Manual verification (multi-root)

Use this to confirm attach metadata, **`PROJECT_HASH`**, and Finish detach without implying any automated pass/fail here.

1. Put or clone a **target** git repo as an **immediate subdirectory** of **`PROJECTS_ROOT`** (see **`.env.local`**).
2. Run **`./scripts/tools/attach-project.sh`** and select that target; confirm Cursor opens the generated **`session.code-workspace`** (or use **`--no-cursor`** and open the workspace file yourself).
3. Start a pipeline (e.g. **`/run`**). In **Init** output, find **`trace-hash-root:`** — it must be the **target** repository root (absolute path), not the orchestrator tree.
4. Complete a run that **edits a file under the target** working tree (implementation **`Task`** **`working_directory`** should be the target).
5. In GitLens (or the Source Control view), confirm history and repo context for that file match the **target** repo, not the orchestrator-only folder.
6. Open **`docs/sessions/<active-session-id>/current.md`** and confirm **`PROJECT_HASH:`** equals the output of **`./scripts/tools/cursor-project-hash.sh <target-root>`** (same path as **`trace-hash-root`**).
7. At **Finish**, accept **detach** when prompted; confirm **`docs/sessions/<id>/session.code-workspace`** is removed and session files under that id remain otherwise intact.

## Step 5: Work on a Feature Branch

```bash
cd myapp/
git checkout -b feature/my-feature
```

Agents are blocked from writing on protected branches (`main`, `master`, `develop`, `release/*`). Always work on a feature branch.

## Upgrading the Workspace

When the upstream workspace has updates:

```bash
./scripts/upgrade.sh           # check what changed
./scripts/upgrade.sh --apply   # fetch, merge, validate
```

Version is tracked via git tags (`YY.M.RELEASE` format). Run `git describe --tags` to see your current version.

## Local Metrics

View your pipeline and agent performance metrics (all local, nothing leaves the machine):

```bash
./scripts/tools/metrics.sh overview    # pipeline health summary
./scripts/tools/metrics.sh agents      # per-step gate decision breakdown
./scripts/tools/metrics.sh specs       # per-spec progress and scores
./scripts/tools/metrics.sh gates       # full gate decision history
./scripts/tools/metrics.sh sessions    # session duration and frequency
```

## Troubleshooting

- **"MCP server not showing up"** — restart Cursor, check JSON syntax, verify command accessible
- **"Atlassian Jira/Confluence unavailable"** — confirm **`Atlassian-MCP-Server`** in `.cursor/mcp.json`, finish OAuth under **Settings → MCP**, and see [atlassian-cursor-workflow.md](reference/atlassian-cursor-workflow.md) (read-only scope; writes not in Phase 1)
- **"Glean MCP not connecting"** — confirm **`Glean`** entry and **`GLEAN_MCP_URL`** (or URL from [Glean MCP Configurator](https://app.glean.com/settings/install?mcpConfigure=true&mcpHost=cursor)) in `.cursor/mcp.json`, finish auth under **Settings → MCP**; see [glean-cursor-workflow.md](reference/glean-cursor-workflow.md)
- **"Rules not loading"** — verify `.mdc` files have valid YAML frontmatter
- **"Hooks not firing"** — check **Settings > Hooks** for errors, verify executable (`chmod +x .cursor/hooks/*.sh`)
- **"Permission denied on setup.sh"** — `chmod +x scripts/setup.sh`
- **"Subagent not activating"** — verify `.md` file has valid frontmatter with `name` and `description`
- **"Write-capable agent blocked"** — one of your child repos is on a protected branch. Switch to a feature branch in that repo: `cd myapp/ && git checkout -b feature/my-work`
- **"/run pipeline stops unexpectedly"** — check spec file for corruption, verify repos exist. Try `--resume` to continue from last successful step.
- **"Session memory stale"** — stale files are cleaned up at next session start if untouched for >24h. Run `scripts/tools/session-memory.sh clear` to reset manually.
