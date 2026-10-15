# Google Antigravity (AGY) Adapter

This directory contains the documentation and adapter mapping for Google Antigravity (AGY) — including Antigravity IDE (VS Code-based) and Antigravity 2.0.

## Overview

Unlike Claude Code and Cursor which install project-level mirrors or user marketplace plugins, Antigravity uses a **Global User Plugin** architecture:
- Plugin path: `~/.gemini/config/plugins/beacon-sdd/`
- Workspace context: Root `AGENTS.md` (read natively by Antigravity)

## Structure

```text
agentic/adapters/antigravity/
├── plugin.json         # Plugin manifest
├── hooks.json          # Lifecycle hooks mapping
├── rules/              # Router & safety rules
│   ├── 00-beacon-router.md
│   └── git-gitlab-mutations.md
├── docs/               # Adapter documentation
│   ├── README.md
│   ├── setup.md
│   ├── skills.md
│   └── hooks.md
└── README.md           # Adapter reference
```

## Quick Start

Run:
```bash
scripts/setup-agentic.sh antigravity
```

This installs the `beacon-sdd` plugin globally into `~/.gemini/config/plugins/beacon-sdd/` and installs `AGENTS.md` to your workspace root.
