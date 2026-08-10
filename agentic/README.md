# Agentic — canonical SDD framework source

This directory is the **single source of truth** for the SDD/agentic framework.
**No IDE should auto-discover it** (not `.claude/`, not `.cursor/`, not `.agents/`).

Membership rule: **if it lives here, it is framework.** Project-specific overlays stay in the
IDE runtime dirs and are never sourced from `agentic/`.

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
scripts/setup-agentic.sh cursor        # → .cursor/ + .agents/skills/ + docs/adapters/cursor/
scripts/setup-agentic.sh antigravity   # → .agent/ (stub)
scripts/setup-agentic.sh all           # claude + cursor + antigravity
```

**Generated (gitignored):** `.claude/` framework mirror, `.cursor/`, `.agents/`, root `CLAUDE.md`,
`docs/adapters/`. **Tracked overlays:** `.claude/**/bcs-*` only. **Tracked source:** `agentic/`.

**Claude** copies framework verbatim and installs root `CLAUDE.md` from
`adapters/claude/CLAUDE.md`. **Cursor** adapts paths, installs `.cursor/rules/*.mdc` (always-on),
does **not** mirror commands as skills, and by default **deactivates** the managed Claude mirror
(overlays kept). Use `--keep-claude` for dual-IDE. See `adapters/*/README.md` and
`agentic/docs/README.md`.

Each runtime root gets an `.agentic-managed` manifest. Prune only removes managed paths that
disappeared from `agentic/` — overlays are never deleted.

Edit files **here**, then re-run setup for the IDE(s) you use.
