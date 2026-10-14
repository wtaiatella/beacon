# Agentic documentation map

Canonical docs for the SDD framework and IDE adapters live under **`agentic/`**.
Runtime IDE trees (`.claude/`, `.cursor/**/beacon/`, `.agents/` framework leftovers) and root `CLAUDE.md` are **generated**. Project files elsewhere under `.cursor/` stay tracked.

## Layout

```text
agentic/
├── docs/                          # Shared SDD / workspace docs (tracked)
│   ├── README.md                  # this map
│   └── setup.md                   # setup-agentic.sh (all IDEs)
└── adapters/
    ├── claude/
    │   ├── CLAUDE.md              # → repo-root CLAUDE.md on `setup claude`
    │   └── docs/                  # → docs/adapters/claude/ on setup
    ├── cursor/
    │   ├── rules/*.mdc            # → .cursor/rules/
    │   └── docs/                  # → docs/adapters/cursor/ on setup
    └── antigravity/               # stub
```

## What stays in repo-root `docs/`

| Path | Why |
|------|-----|
| `docs/run-pipeline-reference.md` | Shared pipeline human reference (not IDE-specific) |
| `docs/reference/mcp-servers-inventory.md` | Enterprise / product context |
| `docs/reference/*-cursor-workflow.md` | Product workflows (Atlassian/GitLab/Glean) — Cursor-named historically; still shared process docs |
| `docs/reference/nested-task-audit.md` | Shared orchestration invariant |
| `docs/model-catalog.md` | Shared |
| `<ticket>/_run/` | Run scratch for one ticket (timeline, pre-plan, scanners, diffs). Tracked with the ticket folder. |
| `docs/specs/` | Tracked — ticket folders are this workspace's project history |

These are **not** installed by `setup-agentic.sh`. Edit them in place under `docs/`.

## What is installed by setup

| Target | `setup … claude` | `setup … cursor` |
|--------|------------------|------------------|
| Root `CLAUDE.md` | from `adapters/claude/CLAUDE.md` | *(unchanged / not required)* |
| `docs/adapters/claude/` | from `adapters/claude/docs/` | pruned if was managed* |
| `docs/adapters/cursor/` | — | from `adapters/cursor/docs/` |
| `.claude/*` framework | agents/skills/commands/hooks | deactivated by default |
| `.cursor/**/beacon/` | — | Cursor framework runtime. Project skills outside `beacon/` stay tracked. `hooks.json` is regenerated at `.cursor/hooks.json` |

\*Doc installs use `docs/adapters/.agentic-managed` so only generated adapter doc trees are pruned.

## Stale docs removed / replaced

- `docs/claude-compat.md` → `agentic/adapters/claude/docs/runtime.md` (new dual-adapter reality)
- `docs/setup.md` → `agentic/docs/setup.md` (setup-agentic.sh); thin pointer may remain at `docs/setup.md`
- `docs/reference/cursor-*.md` → `agentic/adapters/cursor/docs/*.md`
