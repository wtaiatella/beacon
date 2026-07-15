# Cursor Agent Skills Reference

Condensed reference for the Agent Skills format, discovery, and invocation. Source: official Cursor skills documentation.

## What Skills Are

Skills are portable, version-controlled packages that teach agents how to perform domain-specific tasks. They can include scripts, templates, and references.

## SKILL.md Format

Each skill is a folder containing a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: my-skill
description: Short description of what this skill does and when to use it.
---

# My Skill

Detailed instructions for the agent.

## When to Use
- Use this skill when...

## Instructions
- Step-by-step guidance
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier. Lowercase, numbers, hyphens. Must match parent folder name. |
| `description` | Yes | What the skill does and when to use it. Agent uses this for relevance. |
| `license` | No | License name or reference. |
| `compatibility` | No | Environment requirements (system packages, network access). |
| `metadata` | No | Arbitrary key-value mapping. |
| `disable-model-invocation` | No | If true, only included when explicitly invoked via `/skill-name`. |

## Discovery Directories

Skills are automatically loaded from these locations:

| Location | Scope |
|----------|-------|
| `.agents/skills/` | Project |
| `.cursor/skills/` | Project |
| `~/.cursor/skills/` | User (global) |
| `.claude/skills/`, `.codex/skills/` | Project (compatibility) |
| `~/.claude/skills/`, `~/.codex/skills/` | User (compatibility) |

## Directory Structure

```
.cursor/skills/
└── my-skill/
    ├── SKILL.md           # Required
    ├── scripts/           # Optional: executable code agents can run
    │   └── deploy.sh
    ├── references/        # Optional: additional docs loaded on demand
    │   └── REFERENCE.md
    └── assets/            # Optional: templates, configs, data files
        └── template.json
```

## Invocation

### Automatic (default)
Agent reads available skill descriptions and decides when they are relevant based on context.

### Manual
Type `/skill-name` in Agent chat to explicitly invoke a skill.

### Disabled auto-invocation
Set `disable-model-invocation: true` to make a skill manual-only (like a slash command). The skill is only included in context when you explicitly type `/skill-name`.

## Including Scripts

Reference scripts in SKILL.md using relative paths from the skill root:

```markdown
Run the deployment script: `scripts/deploy.sh <environment>`
```

Scripts can be written in any language (bash, Python, JS, etc.). They should be self-contained with helpful error messages.

## Migration from Rules/Commands

Use `/migrate-to-skills` in Agent chat to convert:
- **Dynamic rules** (Apply Intelligently) -> standard skills
- **Slash commands** -> skills with `disable-model-invocation: true`

Rules with `alwaysApply: true` or specific globs are not migrated.

## Best Practices

- Keep SKILL.md focused; move detailed reference to `references/` directory
- Skills load resources progressively (on demand) for token efficiency
- Include a "When to Use" section for clear agent decision-making
- Scripts should handle edge cases gracefully with clear error messages
