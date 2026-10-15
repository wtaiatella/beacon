# Cursor MCP (Model Context Protocol) Reference

Condensed reference for MCP server configuration, transports, and capabilities. Source: official Cursor MCP documentation.

For **Jira / Confluence** (read-only onboarding, auth, troubleshooting), see **[atlassian-cursor-workflow.md](atlassian-cursor-workflow.md)** — complementary to GitLab workflow docs, not a duplicate of transport details below.

For **Glean** (optional enterprise search, org-wide institutional context), see **[glean-cursor-workflow.md](glean-cursor-workflow.md)**.

## Integration quick reference

| Optional integration | Primary doc |
|----------------------|-------------|
| **All servers in `.cursor/mcp.json` (tools, read/write)** | [mcp-servers-inventory.md](mcp-servers-inventory.md) |
| GitLab (stdio `@zereight/mcp-gitlab` → SCM `/api/v4`) | [gitlab-cursor-workflow.md](gitlab-cursor-workflow.md) |
| Atlassian Rovo (Jira / Confluence read) | [atlassian-cursor-workflow.md](atlassian-cursor-workflow.md) |
| Glean (enterprise search) | [glean-cursor-workflow.md](glean-cursor-workflow.md) |

## What MCP Does

MCP connects Cursor to external tools and data sources. MCP servers expose capabilities through the protocol that Agent can use automatically.

## Transport Types

| Transport | Environment | Deployment | Auth |
|-----------|-------------|------------|------|
| `stdio` | Local | Cursor manages process | Manual (env vars) |
| `SSE` | Local/Remote | Deploy as server | OAuth |
| `Streamable HTTP` | Local/Remote | Deploy as server | OAuth |

## Configuration

### Config Locations

| Scope | Path |
|-------|------|
| Project | `.cursor/mcp.json` |
| Global | `~/.cursor/mcp.json` |

### Framework repo (agentic-workspace) conventions

- **Committed** `.cursor/mcp.json` usually lists **optional** servers (GitLab, Atlassian Rovo, Glean) with **canonical** or **env-based** URLs — **no** API tokens or OAuth secrets in git. Use **`${env:NAME}`** in **`url`**, **`headers`**, and **`auth`** fields where teams need machine-specific or tenant-specific values.
- **Local overrides:** Developers may add blocks or change URLs **without** committing (or use **global** `~/.cursor/mcp.json`) so internal hostnames stay off the default branch.
- **Agent behavior:** Personas **degrade gracefully** when MCP is missing; see **`00-workspace-router.mdc`** and **[atlassian-cursor-workflow.md](atlassian-cursor-workflow.md)**, **[glean-cursor-workflow.md](glean-cursor-workflow.md)**, **[gitlab-cursor-workflow.md](gitlab-cursor-workflow.md)**.

### STDIO Server (Local)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "mcp-server"],
      "env": {
        "API_KEY": "${env:MY_API_KEY}"
      }
    }
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | Command to start the server. Must be on PATH or full path. |
| `args` | No | Arguments passed to command. |
| `env` | No | Environment variables for the server. |
| `envFile` | No | Path to .env file (STDIO only, not for remote servers). |

### Remote Server (HTTP/SSE)

```json
{
  "mcpServers": {
    "server-name": {
      "url": "http://localhost:3000/mcp",
      "headers": {
        "Authorization": "Bearer ${env:MY_TOKEN}"
      }
    }
  }
}
```

### Remote Server with OAuth

```json
{
  "mcpServers": {
    "oauth-server": {
      "url": "https://api.example.com/mcp",
      "auth": {
        "CLIENT_ID": "${env:MCP_CLIENT_ID}",
        "CLIENT_SECRET": "${env:MCP_CLIENT_SECRET}",
        "scopes": ["read", "write"]
      }
    }
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `CLIENT_ID` | Yes | OAuth 2.0 Client ID from MCP provider. |
| `CLIENT_SECRET` | No | OAuth 2.0 Client Secret (if confidential client). |
| `scopes` | No | OAuth scopes to request. |

**Static redirect URL** (register with provider): `cursor://anysphere.cursor-mcp/oauth/callback`

## Config Interpolation

Variables supported in `command`, `args`, `env`, `url`, and `headers`:

| Variable | Description |
|----------|-------------|
| `${env:NAME}` | Environment variable |
| `${userHome}` | Home directory path |
| `${workspaceFolder}` | Project root |
| `${workspaceFolderBasename}` | Name of project root directory |
| `${pathSeparator}`, `${/}` | OS path separator |

## Protocol Capabilities

| Feature | Support | Description |
|---------|---------|-------------|
| Tools | Supported | Functions for the AI model to execute |
| Prompts | Supported | Templated messages and workflows |
| Resources | Supported | Structured data sources to read/reference |
| Roots | Supported | Server-initiated URI/filesystem boundary inquiries |
| Elicitation | Supported | Server-initiated requests for user info |
| Apps | Supported | Interactive UI views returned by MCP tools |

## AskQuestion (structured multiple choice)

Cursor can present **multiple-choice questions** via the **`AskQuestion`** tool (labels map to option IDs the user selects).

| Mode | Typical behavior |
|------|------------------|
| **Plan mode** | `AskQuestion` is commonly available for structured checkpoints. |
| **Agent mode** | Availability may **vary** by Cursor version and model; there are [community requests](https://forum.cursor.com/t/allow-askquestion-tool-calls-in-agent-mode-or-any-mode/152517) to make `AskQuestion` consistently available outside Plan mode. |

**Run-pipeline Finish:** orchestrators should **prefer `AskQuestion`** for commit-message options (including **do not commit** and **manual**), push yes/no, and MR yes/no when the tool is present; **fall back** to numbered chat prompts if not. **Selecting a suggested commit message** is treated as consent to run **`git commit`** with that message (see **`.cursor/skills/beacon/run-pipeline/SKILL.md`** § 9). **Push** and **MR** remain user-confirmed suggestions only — no autonomous `git push` or GitLab writes.

## Using MCP in Chat

- Agent automatically uses MCP tools listed under Available Tools when relevant
- Works in Plan Mode as well as Agent Mode
- Ask for a specific tool by name or describe what you need
- Enable/disable tools from Cursor Settings

### Tool Approval

- **Default:** Agent asks before using MCP tools
- **Auto-run:** Enable for tools to run without asking (like terminal commands)
- **Pre-configure:** Add auto-run tools to `~/.cursor/permissions.json`

### Images as Context

MCP servers can return base64-encoded images. Cursor attaches them to chat and vision-capable models analyze them.

## Extension API

Register MCP servers programmatically: `vscode.cursor.mcp.registerServer()`

## Security Considerations

- Verify source: only install from trusted developers/repositories
- Review permissions: check what data and APIs the server accesses
- Limit API keys: use restricted keys with minimal permissions
- Audit code: review server source for critical integrations
- MCP servers can access external services and execute code on your behalf
