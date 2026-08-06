# Contributing

Contribution guide for the shared agentic development framework.

## What This Repo Is

A shared framework for agentic development. It is **not** where your application code or specs live. Your specs, target repos, and runtime artifacts are local and gitignored.

## What You Can Contribute

- New or improved subagent personas (`.cursor/agents/*.md`) — keep **must-follow** rules in YAML **`description`** and the **top** of the file; Cursor may preview or condense long agent definitions (see **Agent definition files** in `00-workspace-router.mdc`)
- New or improved skills (`.cursor/skills/*/SKILL.md`)
- New or improved tool scripts (`scripts/tools/*.sh`)
- New or improved hooks (`.cursor/hooks.json` + `.cursor/hooks/*.sh`)
- Updates to the workspace router rule (`.cursor/rules/00-workspace-router.mdc`)
- New roadmap items or status updates (`docs/roadmaps/` — see `docs/roadmaps/README.md`)
- Documentation improvements (`docs/`, `README.md`)
- Bug fixes in any of the above

## What You Should NOT Commit

- Your local specs, including each ticket folder's `summary.md` (`docs/specs/` is gitignored)
- Session memory files (`docs/sessions/` is gitignored)
- Audit logs (`docs/audit.log` is gitignored)
- Usage event logs (`docs/usage-events.tsv` is gitignored — optional ROAD-18 granular cost rows; example schema in `docs/usage-events.example.tsv`)
- Child repository code (gitignored)
- Raw API tokens, OAuth client secrets, or host-specific internal URLs that your policy keeps out of git (prefer **`${env:…}`** in `.cursor/mcp.json` — see **`docs/reference/cursor-mcp.md`**)
- `.env` files, secrets, or credentials
- **Repository-root session shims:** Do not add **`exploration`** or **`qa-artifacts`** at the workspace root (symlink or directory) to “mirror” paths under **`docs/sessions/`**. Use canonical dirs only: **`docs/sessions/<session-id>/artifacts/explorer/`** and **`.../artifacts/scanners/`** (see **`run-pipeline`** skill — no backward-compat symlinks for migrations). Root-level names are **`/exploration`** and **`/qa-artifacts`** in **`.gitignore`**; **`./scripts/tools/lint-check.sh .`** fails if the root contains disallowed session symlinks.

### For reviewers: session paths and symlinks

When reviewing MRs that touch **session storage**, **`.gitignore`**, or **`scripts/tools/lint-check.sh`**, confirm the change does **not** reintroduce root-level **`exploration`** / **`qa-artifacts`** shortcuts or scripts that create them. CI runs **`./scripts/tools/lint-check.sh .`** on the validate job; if a PR adds suspicious root entries, ask the author to run that command locally and align with **`.cursor/skills/run-pipeline/SKILL.md`** (hard cutover for path migrations).

## Optional GitLab MR workflow

This repo’s merge requests go through **GitLab**. After implementation, use the **run-pipeline Finish** prompts: **commit** (optional — if you pick a suggested message, the orchestrator may run **`git commit`** for you; choose **do not commit** or **manual** to skip), then **push** and **MR** (always your confirmation; orchestrators **never** auto-push). Orchestrators **prefer** the **`AskQuestion`** tool when available (see **`docs/reference/cursor-mcp.md`**). Persona agents never run **`git commit`** or **`git push`**.

**GitLab MCP:** The committed **`.cursor/mcp.json`** includes a **GitLab** HTTP MCP entry (URL is team-specific; it may be **gitlab.com**, self-managed, or an org gateway — see **`docs/reference/gitlab-cursor-workflow.md`**). Authenticate per your host. For MR body text from a spec and label hints, use **`scripts/tools/mr-description-from-spec.sh`**.

### Optional MCP and agent toolboxes

When you **add** or **change** MCP servers (beyond the shipped optional blocks):

1. Edit **`.cursor/mcp.json`** (and/or **global** `~/.cursor/mcp.json`) using **`${env:…}`** for tenant URLs and tokens where possible — **`docs/reference/cursor-mcp.md`**.
2. Follow the integration guides: **`docs/reference/gitlab-cursor-workflow.md`**, **`docs/reference/atlassian-cursor-workflow.md`** (ROAD-01 read-only), **`docs/reference/glean-cursor-workflow.md`** (ROAD-26), **`docs/reference/arc-mcp-workflow.md`** (ROAD-25), and **`docs/arc-onboarding.md`** (ARC: **Cursor MCP config** vs **`avatax-release-central`** server-side onboarding — `projects_config.py`, `feature_registry.py`, Confluence ATPE indexes; **no secrets** in git).
3. Update **Toolbox** sections in **`.cursor/agents/*.md`** for any persona that should prefer those tools when loaded, and align **`00-workspace-router.mdc`** (optional MCP / search-source table) if discovery order or tool names change.
4. Run **`./scripts/setup.sh`** so JSON parse checks still pass.

**`/run --manual`** (manual **step** gates) is unrelated to MCP configuration; see **`.cursor/skills/run-pipeline/SKILL.md`** and **`docs/run-pipeline-reference.md`**.

## How to Propose Changes

1. Create a feature branch from `main`
2. Make changes following existing patterns
3. Test: verify rules load, agents activate, scripts run
4. Run `./scripts/setup.sh` to validate workspace integrity
5. Open an MR with clear description
6. Include a **Testing** section in the MR

### Workspace content linters (specs and agents)

Before you open an MR that touches `docs/specs/*-spec.md` or `.cursor/agents/*.md`, run the **content linters** from the repository root (same rules as CI’s validate stage):

```bash
# Run both (recommended)
./scripts/tools/lint-workspace-content.sh
```

Or run each linter separately:

```bash
./scripts/tools/lint-workspace-specs.sh   # docs/specs/*-spec.md
./scripts/tools/lint-workspace-agents.sh # .cursor/agents/*.md
```

- Exit code **0** means all checked files passed. If there are no `*-spec.md` files under `docs/specs/`, the spec linter exits 0 with a short “nothing to validate” message.
- Exit code **1** means at least one file failed; messages are prefixed so you can find the issue quickly.

Use `./scripts/tools/<script> --help` for a short usage summary. For manual negative checks (intentional failures), see `scripts/tools/tests/README.md`.

Before you open an MR that changes **`.cursor/skills/run-pipeline/SKILL.md`** or **`.cursor/rules/00-workspace-router.mdc`**, run **`./scripts/tools/verify-preplan-orchestration-docs.sh`** from the repository root. It enforces the same **blocking** pre-plan orchestration invariants as the **docs-check** job (flat MCP gather, Wave 1 skip rules, merge + gate, merged brief / summarized `Pre-plan context`).

Before you open an MR that changes **`.cursor/skills/run-pipeline/SKILL.md`**, **`.cursor/agents/qa.md`**, **`.cursor/agents/summary.md`**, or **`.cursor/rules/git-gitlab-mutations.mdc`**, run **`./scripts/tools/verify-qa-git-boundaries.sh`** from the repository root. It enforces **blocking** QA / Git boundary invariants aligned with **docs-check**: § 7.1 post-QA scrum (orchestrator does not apply QA **Proposed spec updates** until **`Task(scrum)`** **PROCEED**), no nested **`Task(spec-validator)`** / **`Task(security-scanner)`** from **`Task(qa)`**, Finish **§ 9** MR safety (no **`glab mr create`** / mutating GitLab API from the orchestrator), and the **git-gitlab-mutations** push/MR rules.

**CI pipeline runs automatically on every MR** (`.gitlab-ci.yml`). It validates:
- Full workspace **`./scripts/tools/lint-check.sh .`** (validate job `workspace-lint-check`; same command as local runs in **No Historical Tracking IDs in Prompts** below)
- All agent and skill files have valid YAML frontmatter with required fields
- All JSON files parse correctly (`mcp.json`, `hooks.json`)
- All shell scripts have valid syntax and are executable
- Every hook script is registered in `hooks.json` and vice versa (bidirectional sync)
- No `.env` files or obvious secrets are committed
- Documentation was updated when framework files changed (warning, non-blocking)
- Manual release tagging on main (`YY.M.RELEASE` format via CI job)

No hardcoded counts — validation is relationship-based. Add a new agent, skill, hook, or script and the pipeline validates it has valid structure and is properly registered. No manual count updates needed.

If the pipeline fails, fix the issue before requesting review. Documentation warnings are non-blocking but should be addressed.

## Roadmap vs plan

- **`/roadmap`** (`.cursor/agents/roadmap.md`) turns directories, doc paths, and vision text into **roadmap-shaped** **`ROAD-NN`** sections for the **committed** backlog tree (**`docs/roadmaps/`** by default, or **`ROADMAP_FILE`** as a **directory** root for another checkout). It does **not** create `docs/specs/*`.
- **`/plan`** produces **architecture specs** and, when **`ROAD-XX`** is in scope, runs a **best-effort implementation-status** pass against deliverables before writing the spec.
- **Helpers:** `scripts/tools/roadmap-next.sh` (next id), `scripts/tools/roadmap-validate.sh` (consistency checks; use before MRs that touch the roadmap).

## No Historical Tracking IDs in Prompts

Do **not** embed historical initiative tracking IDs matching **`ROAD-<number>`** (digits after the hyphen) in:

- **`.cursor/rules/`**
- **`.cursor/skills/`**
- **`.cursor/agents/`**

Those paths are **permanent prompts** for agents and tooling; IDs waste tokens and age poorly. Describe **current behavior** in plain language instead.

**Enforcement:** From the repository root, run **`./scripts/tools/lint-check.sh .`**. The script (1) scans those three directories (when present under the lint target) for `ROAD-[0-9]+` and fails with a non-zero exit if any match is found; (2) scans **`.cursor/agents/*.md`** for disallowed MCP toolbox patterns—**`Optional MCP`**, **`call_mcp_tool`**, and **`MCP server`** / **`MCP servers`** (case-insensitive)—in every file **except** allowlisted **`mcp-*.md`**, **`plan.md`**, and **`pre-plan-triage.md`**; (3) scans **`.cursor/agents/*.md`** and **`.cursor/skills/**/*.md`** for instructional shell one-liners (**`python3 -c`**, **`git mv`**, **`git commit`**, **`awk '{`**) outside markdown fences, with exemptions for prohibition wording, first-party script references (**`pipeline-finish`**, **`git-inspect.sh`**, **`archive-roadmap.sh`**, **`query-transcript.py`**, **`audit-session-trace`**), and lines marked with **`<!-- lint:allow-subagent-shell -->`**. Details: **`scripts/tools/lint-check.sh`** header and **`scripts/tools/lint-subagent-prompt-patterns.py`**. For an automated clean-tree plus ROAD negative-case check, run **`./scripts/tools/tests/test-lint-check-road-guard.sh`**; for the subagent shell guard, **`./scripts/tools/tests/test-lint-check-subagent-shell-patterns.sh`** (see **`scripts/tools/tests/README.md`**). To confirm the MCP guard manually, temporarily add a line containing **`Optional MCP`** to a non-allowlisted agent (e.g. **`dev.md`**), run **`./scripts/tools/lint-check.sh .`**, expect failure, then revert.

**Exempt:** Roadmap **content** and **workflow** documentation under **`docs/roadmaps/`** (and linked roadmap how-to docs) are the right place for `ROAD-*` filenames and references. This prompt-hygiene rule does **not** apply there.

## Conventions

### Spec filenames (optional timestamps)

Architecture specs live under **`docs/specs/`** (gitignored locally). The baseline name is **`{YYYY-MM-DD}-{kebab-slug}-spec.md`**. Optional **UTC timestamp** affixes help when several drafts exist the same day or you want sortable precision; see **`.cursor/skills/generate-spec/SKILL.md`**.

Examples (validated by `lint-workspace-specs.sh` alongside the default `YYYY-MM-DD-{slug}-spec.md` form):

- `2026-04-10-road-35-session-storage-staged-preplan-spec.md` — default pattern
- `2026-04-10T2057Z-road-35-session-storage-staged-preplan-spec.md` — `YYYY-MM-DDTHHMMSSZ-` prefix on the kebab slug
- `2026-04-10-2057-road-35-session-storage-staged-preplan-spec.md` — `YYYY-MM-DD-HHMM-` before the kebab slug (same day, multiple drafts)

### Subagents

- YAML frontmatter: `name`, `description`, `model` (`default` | `inherit` | specific ID from `docs/model-catalog.md`), optionally `readonly`
- **8 sections** for persona subagents: Role, Trigger & Input, Toolbox, Workflow, Spec Interaction, Completion Output, Error Handling, Guardrails
- `description` **must** include the substring **Use when** (case-insensitive; enforced by `lint-workspace-agents.sh` in CI)

### Supporting Subagents (dual-mode)

- YAML frontmatter: `model`: `default`, `inherit`, or specific ID; `readonly`: `true`
- Simpler structure: Name, Description, Toolbox, Structured Output
- Descriptions should include "Use when..."
- **Pre-plan MCP specialists** (`pre-plan-triage`, `mcp-glean`, `mcp-confluence`, `mcp-jira`, `mcp-gitlab`) are **read-only** and are delegated from the **main session** during **`/run`** pre-plan (see **`.cursor/skills/run-pipeline/SKILL.md`**), not nested inside **`Task(plan)`** — avoids duplicate MCP gather; **`00-workspace-router.mdc`** lists triggers and boundaries.

### Per-Persona Reviewers

- Common output format: Score, Findings table, Confidence Factors, Verdict, Rework Instructions
- Must define domain-specific confidence factors with score/100

### Skills

- `SKILL.md` under a descriptive directory; YAML frontmatter with `name` and `description`
- Use `references/` for progressive disclosure

### Scripts

- `#!/usr/bin/env bash`, executable, `--help` flag, auto-detect tech stack
- Descriptive header comment explaining purpose (2-4 lines after shebang)

### Hooks

- `#!/usr/bin/env bash`, executable, read JSON from stdin, return JSON to stdout
- Descriptive header comment explaining purpose, inputs, and behavior
- Config in `.cursor/hooks.json`, scripts in `.cursor/hooks/`

## Adding a New Persona

1. Create `.cursor/agents/name.md` (all 8 sections, valid frontmatter with name/description/model)
2. Optionally create `.cursor/agents/name-reviewer.md`
3. Optionally create `.cursor/skills/name-related-skill/SKILL.md`
4. Update `00-workspace-router.mdc` to list the new trigger
5. If a reviewer was added: update `.cursor/skills/run-pipeline/SKILL.md` (and the router if needed) so orchestrated mode delegates to it
6. Update `README.md` persona table
7. Run `./scripts/setup.sh` to validate (no count updates needed — validation is automatic)

**Note:** No trigger rule is needed — Cursor natively routes `/name`. No hardcoded counts to update — setup.sh and CI validate structure and relationships dynamically.
