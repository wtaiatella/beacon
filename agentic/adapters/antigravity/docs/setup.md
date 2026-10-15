# Antigravity Adapter Setup & Installation

## Prerequisites

- Google Antigravity IDE or Antigravity 2.0 installed.
- Node.js (v18+) for lifecycle hook execution.

## Installation

Install the adapter using the unified setup script:

```bash
# Install Antigravity adapter only
scripts/setup-agentic.sh antigravity

# Install all supported adapters (Claude + Cursor + Antigravity)
scripts/setup-agentic.sh all
```

### Dry Run

Preview changes without writing files:

```bash
scripts/setup-agentic.sh antigravity --dry-run
```

## What Gets Installed

1. **Global Plugin (`~/.gemini/config/plugins/beacon-sdd/`)**:
   - `plugin.json`: Plugin manifest.
   - `skills/`: Complete catalog of framework skills and persona skills.
   - `rules/`: Always-on routing and Git guardrails.
   - `hooks/`: Lifecycle hook scripts.
   - `hooks.json`: Lifecycle hook definitions for Antigravity.
   - `.sdd-source-stamp`: Source hash to avoid redundant synchronization.

2. **Workspace Control (`AGENTS.md`)**:
   - Copied to the workspace root: `AGENTS.md`.
   - Antigravity automatically detects and loads `AGENTS.md` in any opened project.

3. **Adapter Documentation (`docs/adapters/antigravity/`)**:
   - Generated documentation reflecting the installed configuration.

## Uninstallation / Prune

Running setup automatically manages framework files using the `.agentic-managed` manifest and removes orphaned entries when framework files change.
To remove the global plugin manually:

```bash
rm -rf ~/.gemini/config/plugins/beacon-sdd
```
