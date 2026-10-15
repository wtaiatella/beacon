# Antigravity Skills & Personas Reference

In Google Antigravity, capabilities and personas are exposed as **Skills**.

## How Skills Work in Antigravity

- Skills live in `skills/<skill_name>/SKILL.md`.
- Each `SKILL.md` contains YAML frontmatter with `name` and `description`.
- **Progressive Disclosure:** Antigravity injects only skill names and descriptions into the agent's system prompt. When the user invokes a command or the orchestrator requires a persona, the full instructions are read on-demand via `view_file`.

## Beacon Skills Catalog

The `beacon-sdd` plugin exposes:

1. **Pipeline & Orchestration Skills:**
   - `run`: Handles `/run` command invocations.
   - `run-pipeline`: Authoritative BMAD+SDD workflow engine.
   - `confidence-scoring`: Confidence threshold assessment.

2. **Persona Skills (Direct Slash Commands):**
   - `dev`: Handles `/dev` — implements tasks from architecture specs.
   - `qa`: Handles `/qa` — audits code, runs tests, writes `qa-report.md`.
   - `scrum`: Handles `/scrum` — review gates and ticket progression.
   - `prd`: Handles `/prd` — product requirements generation.
   - `spectech`: Handles `/spectech` — technical architecture design.
   - `tasks`: Handles `/tasks` — task breakdown and domain tagging.
   - `fix`: Handles `/fix` — targeted debugging and fixes.
   - `do`: Handles `/do` — ad-hoc operational tasks.
   - `sre`: Handles `/sre` — platform and reliability engineering.
   - `data`: Handles `/data` — data and pipeline engineering.
   - `summary`: Handles `/summary` — post-pipeline handoff notes.

3. **Utility Skills:**
   - `clone`: Clones child repositories.
   - `rebase`: Multi-repo git synchronization.
   - `kb` / `kb-refresh` / `kb-concentrator`: Knowledge base curation.
   - `setup-workspace`: Tool and MCP registry configuration.

## Command Invocations in Chat

Users trigger skills by typing slash commands in the Antigravity chat:
```text
/run docs/specs/2026-10-15-feature/
/dev docs/specs/2026-10-15-feature/
/qa docs/specs/2026-10-15-feature/
/scrum
```
Antigravity matches the command to the skill's description, activates the skill, and follows its runbook.
