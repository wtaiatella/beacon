# Cursor Rules Reference

Condensed reference for rule types, configuration, and precedence. Source: official Cursor rules documentation.

## What Rules Do

Rules provide persistent, reusable system-level instructions to Agent. When applied, rule contents are included at the start of the model context.

## Rule Types

| Type | Trigger | Frontmatter |
|------|---------|-------------|
| **Always Apply** | Every chat session | `alwaysApply: true` |
| **Apply Intelligently** | Agent decides based on `description` | `alwaysApply: false` (no globs) |
| **Specific Files** | When file matches glob pattern | `globs: "**/*.ts"` |
| **Manual** | When @-mentioned in chat (e.g. `@my-rule`) | No `alwaysApply`, no `globs` |

## File Format

Rules live in `.cursor/rules/` as `.mdc` or `.md` files. Frontmatter controls behavior.

```markdown
---
description: "Standards for frontend components and API validation"
alwaysApply: false
globs: "src/components/**/*.tsx"
---

- Use functional components with TypeScript
- Validate all API responses with zod schemas
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | What the rule covers. Used by Agent to decide relevance for "Apply Intelligently" rules. |
| `alwaysApply` | boolean | If true, included in every chat session. |
| `globs` | string/array | File patterns that trigger the rule when matching files are in context. |

## File Locations

| Type | Location | Scope |
|------|----------|-------|
| Project rules | `.cursor/rules/` | Current project only |
| User rules | Cursor Settings > Rules | All projects |
| Team rules | Dashboard (Teams/Enterprise) | All team members |

## Precedence

Rules are applied in this order (all merge; earlier sources take precedence on conflict):

1. **Team Rules** (Enterprise/Teams plan)
2. **Project Rules** (`.cursor/rules/`)
3. **User Rules** (Cursor Settings)

### Team Rules

- Created and managed from the Cursor dashboard
- Can be **enforced** (required, cannot be disabled) or **optional** (users can toggle off)
- Support glob patterns for file-scoped application
- Free-form text content (no folder structure like project rules)

## AGENTS.md Alternative

`AGENTS.md` is a plain markdown file for simple agent instructions. Place in project root or subdirectories. No frontmatter or metadata — just markdown.

```markdown
# Project Instructions

## Code Style
- Use TypeScript for all new files
- Prefer functional components in React
```

Cursor supports `AGENTS.md` in the project root and subdirectories. Use it as a lightweight alternative when you don't need structured rule configuration.

## Best Practices

- Keep rules under 500 lines
- Split large rules into multiple composable files
- Provide concrete examples or reference files
- Write rules like clear internal docs
- Reference files instead of copying contents (prevents staleness)
- Check rules into git so the team benefits
- Add rules only when Agent makes the same mistake repeatedly

## What to Avoid

- Copying entire style guides (use a linter instead)
- Documenting every possible command (Agent knows common tools)
- Instructions for edge cases that rarely apply
- Duplicating what's already in the codebase
