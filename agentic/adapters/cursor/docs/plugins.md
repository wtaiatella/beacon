# Cursor Plugins Reference

Condensed reference for plugin packaging, distribution, and marketplace integration. Source: official Cursor plugins documentation.

## What Plugins Contain

Plugins bundle any combination of these components:

| Component | Description |
|-----------|-------------|
| Rules | Persistent AI guidance and coding standards (`.mdc` files) |
| Skills | Specialized agent capabilities (SKILL.md) |
| Agents | Custom agent configurations and prompts |
| Commands | Agent-executable command files |
| MCP Servers | Model Context Protocol integrations |
| Hooks | Automation scripts triggered by events |

## Plugin Structure

```
my-plugin/
├── .cursor-plugin/
│   └── plugin.json         # Required manifest
├── rules/
│   └── coding-standards.mdc
├── skills/
│   └── code-reviewer/
│       └── SKILL.md
├── agents/
│   └── verifier.md
├── hooks/
│   └── format.sh
└── mcp.json
```

## Manifest (`plugin.json`)

Only `name` is required. Components are discovered automatically from default directories.

```json
{
  "name": "my-plugin",
  "description": "Custom development tools",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

For multi-plugin repositories, add `.cursor-plugin/marketplace.json`.

## Local Testing

Load plugins from `~/.cursor/plugins/local/` during development:

1. Create folder: `~/.cursor/plugins/local/my-plugin`
2. Copy plugin files (ensure `.cursor-plugin/plugin.json` is at root)
3. Restart Cursor or run `Developer: Reload Window`

For faster iteration, symlink your repo:
```bash
ln -s /path/to/my-plugin ~/.cursor/plugins/local/my-plugin
```

## Marketplace

### Public Marketplace
- Browse at `cursor.com/marketplace` or in Cursor's marketplace panel
- Submit for review at `cursor.com/marketplace/publish`
- All plugins are manually reviewed before listing
- Community plugins and MCP servers: `cursor.directory`

### Team Marketplaces (Teams/Enterprise)

| Plan | Limit |
|------|-------|
| Teams | 1 team marketplace |
| Enterprise | Unlimited |

**Setup:**
1. Dashboard > Settings > Plugins
2. Import from GitHub repository URL
3. Set distribution groups and required/optional status

### Required vs Optional Plugins

| Setting | Behavior |
|---------|----------|
| Required | Auto-installed for everyone in distribution group |
| Optional | Available in marketplace panel; users choose to install |

Distribution groups can be controlled with SCIM-synced directory groups.

## Installing Plugins

- **Marketplace:** One-click install from marketplace panel
- **MCP deeplinks:** `cursor://anysphere.cursor-deeplink/mcp/install?name=$NAME&config=$BASE64_ENCODED_CONFIG`
- **Extension API:** `vscode.cursor.plugins.registerPath()` for programmatic registration

## Managing Installed Plugins

- **MCP servers:** Toggle on/off in Settings > Features > Model Context Protocol
- **Rules:** Toggle between Always, Agent Decides, and Manual in Settings > Rules
- **Skills:** Appear in Agent Decides section; invoke manually with `/skill-name`
