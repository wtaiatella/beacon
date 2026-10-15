# Agentic — canonical SDD framework source

This directory is the **single source of truth** for the SDD/agentic framework.
**No IDE should auto-discover it** (not `.claude/`, not `.cursor/`, not `.agents/`).

Membership rule: **if it lives here, it is framework.** Project skills, agents, and commands
stay outside this tree. Setup does not copy or link them.

## Layout

```text
agentic/
├── agents/                 # persona / helper / utility agent defs
├── skills/                 # SKILL.md packages
├── commands/               # thin slash proxies (IDE-agnostic intent)
├── hooks/                  # shared hook scripts (.sh) + lib/
├── docs/                   # shared setup + documentation map
└── adapters/
    ├── claude/             # CLAUDE.md + settings.json + docs/
    ├── cursor/             # hooks.json + rules/*.mdc + docs/
    └── antigravity/        # Antigravity stub (.agent/) mapping
```

## Install

```bash
scripts/setup-agentic.sh claude        # → .claude/ + CLAUDE.md + docs/adapters/claude/
scripts/setup-agentic.sh cursor        # → .cursor/ (agents, hooks, rules, skills)
scripts/setup-agentic.sh antigravity   # → .agent/ (stub)
scripts/setup-agentic.sh all           # claude + cursor + antigravity
```

**Generated (gitignored):** `.claude/` framework mirror, `.cursor/**/beacon/`, root `CLAUDE.md`,
`docs/adapters/`. **Tracked source:** `agentic/`. Project skills, agents, and commands are not
part of this install.

**Claude** copies framework verbatim and installs root `CLAUDE.md` from
`adapters/claude/CLAUDE.md`. **Cursor** adapts paths, installs `.cursor/rules/*.mdc` (always-on),
does **not** mirror commands as skills, and by default **deactivates** the managed Claude mirror
(only paths on `.claude/.agentic-managed`). Use `--keep-claude` for dual-IDE. See
`adapters/*/README.md` and `agentic/docs/README.md`.

Each runtime root gets an `.agentic-managed` manifest. Prune only removes managed paths that
disappeared from `agentic/`. Project skills, agents, and commands are not on that list.

Edit files **here**, then re-run setup for the IDE(s) you use.
