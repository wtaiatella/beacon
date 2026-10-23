# Contributing

Contribution guide for the shared agentic development framework.

## What This Repo Is

A shared, generic SDD framework (`agentic/` is the canonical source) that also doubles as a real
project's own workspace root — see `.gitignore` for the tracking policy. If you're contributing to
the **framework itself** (agents, skills, hooks, scripts under `agentic/`), this guide applies. If
you're just using the framework for your own project's tickets, see `README.md` / `AGENTS.md`
instead.

Framework changes land only in the checkout whose `origin` is this repository and that has no
`upstream` remote. A workspace that tracks Beacon as `upstream` updates the framework with
`scripts/upgrade.sh` and does not merge framework work into its own `main`. The rule agents
follow is **Git and GitLab mutations** in `agentic/AGENTS.md`.

## What You Can Contribute

- New or improved subagent personas (`agentic/agents/*.md`) — keep **must-follow** rules in YAML
  **`description`** and the **top** of the file; installed copies (the Claude plugin, or
  `.cursor/agents/beacon/`) may preview or condense long agent definitions (see **Agent definition
  files** in `agentic/adapters/cursor/rules/00-workspace-router.mdc`)
- New or improved skills (`agentic/skills/*/SKILL.md`)
- New or improved tool scripts (`scripts/tools/*.sh`)
- New or improved hooks (`agentic/hooks/*.sh` shared, or `agentic/adapters/<ide>/hooks/*.sh`
  IDE-specific overlay) + the matching hook-config file per adapter
  (`agentic/adapters/claude/settings.json`, `agentic/adapters/cursor/hooks.json`)
- Updates to the workspace router rule (`agentic/adapters/cursor/rules/00-workspace-router.mdc`)
- Documentation improvements (`docs/`, `README.md`, `AGENTS.md`)
- Bug fixes in any of the above

**Never edit generated trees by hand:** `.claude/`, `.cursor/**/beacon/`, `.agent/`, root `CLAUDE.md` /
`AGENTS.md`, `docs/adapters/`. These are produced by `scripts/setup-agentic.sh` from `agentic/` —
edit the source and re-run the script.

## What You Should NOT Commit

- Leftover `docs/sessions/` folders (gitignored). Run state belongs in `docs/specs/<ticket>/_run/` and is tracked with the ticket.
- Audit logs (`docs/audit.log` is gitignored)
- Usage event logs (`docs/usage-events.tsv` is gitignored — optional ROAD-18 granular cost rows; example schema in `docs/usage-events.example.tsv`)
- Child repository code — `/clone` excludes each one with its own `.gitignore` entry

Note: `docs/specs/` (ticket folders, including each one's `summary.md`) is **tracked** by design in
this workspace — see `.gitignore` for the rationale (this repo doubles as a real project's own
history, not just the SDD framework's dev checkout).
- Raw API tokens, OAuth client secrets, or host-specific internal URLs that your policy keeps out of git (prefer `${env:…}` in `.cursor/mcp.json` / `.mcp.json`)
- `.env` files, secrets, or credentials
- **Repository-root shims:** Do not add **`exploration`** or **`qa-artifacts`** at the workspace root. Canonical dirs are **`<ticket-folder>/_run/explorer/`** and **`<ticket-folder>/_run/scanners/`**. Root-level names are **`/exploration`** and **`/qa-artifacts`** in **`.gitignore`**; **`./scripts/tools/lint-check.sh .`** fails if the root contains those symlinks.

### For reviewers: session paths and symlinks

When reviewing PRs that touch **session storage**, **`.gitignore`**, or **`scripts/tools/lint-check.sh`**, confirm the change does **not** reintroduce root-level **`exploration`** / **`qa-artifacts`** shortcuts or scripts that create them. CI runs **`./scripts/tools/lint-check.sh .`** (see `.github/workflows/ci.yml`); if a PR adds suspicious root entries, ask the author to run that command locally.

## Shipping changes to a project using this framework

This section is about **this repo's own** contribution flow. The framework's own policy for
mutating a **child/target** project repo during `/run` (branch consent, commit/push/MR gating, the
optional GitLab MCP specialist) is normative in `agentic/AGENTS.md` — **Git and GitLab mutations**;
don't duplicate it here.

For changes to the framework itself: open a pull request against `main` on whichever forge you
host this repo on (this framework is forge-agnostic by design — GitHub, GitLab, or otherwise).
CI (`.github/workflows/ci.yml` if hosted on GitHub) validates the workspace on every PR and on
pushes to `main`.

### Optional MCP and agent toolboxes

When you **add** or **change** MCP servers (beyond the shipped optional blocks):

1. Edit **`.cursor/mcp.json`** / **`.mcp.json`** (and/or your IDE's **global** MCP config) using **`${env:…}`** for tenant URLs and tokens where possible — never commit a real token or a company-internal URL as a literal default.
2. Follow the integration guides under **`docs/reference/*-cursor-workflow.md`** for the server you're adding.
3. Update **Toolbox** sections in **`agentic/agents/*.md`** for any persona that should prefer those tools when loaded, and align **`00-workspace-router.mdc`** (optional MCP / search-source table) if discovery order or tool names change.
4. Run **`./scripts/setup.sh`** so JSON parse checks still pass.

**`/run --manual`** (manual **step** gates) is unrelated to MCP configuration; see **`agentic/skills/run-pipeline/SKILL.md`** and **`docs/run-pipeline-reference.md`**.

## How to Propose Changes

1. Create a feature branch from `main`
2. Make changes following existing patterns
3. Test: re-run `scripts/setup-agentic.sh <claude|cursor|all>` and confirm agents/skills/hooks install and activate
4. Run `./scripts/setup.sh` to validate workspace integrity
5. Open a pull request with a clear description
6. Include a **Testing** section in the PR

### Workspace content linter (agents)

Before you open a PR that touches `agentic/agents/*.md`, run the **content linter** from the repository root (same command CI runs):

```bash
./scripts/tools/lint-workspace-agents.sh
```

- Exit code **0** means all checked files passed.
- Exit code **1** means at least one file failed; messages are prefixed so you can find the issue quickly.

Use `./scripts/tools/<script> --help` for a short usage summary. For manual negative checks (intentional failures), see `scripts/tools/tests/README.md`.

Before you open a PR that changes **`agentic/skills/run-pipeline/SKILL.md`** or **`agentic/adapters/cursor/rules/00-workspace-router.mdc`**, run **`./scripts/tools/verify-preplan-orchestration-docs.sh`** from the repository root. It enforces the same **blocking** pre-plan orchestration invariants as CI's `docs-check` job (flat Task orchestration, enterprise-wave skip rules, merge + gate, merged brief / summarized `Pre-plan context`).

Before you open a PR that changes **`agentic/skills/run-pipeline/SKILL.md`**, **`agentic/agents/qa.md`**, **`agentic/agents/summary.md`**, or **`agentic/adapters/cursor/rules/git-gitlab-mutations.mdc`**, run **`./scripts/tools/verify-qa-git-boundaries.sh`** from the repository root. It enforces **blocking** QA / Git boundary invariants aligned with `docs-check`: § 7.1 post-QA scrum (orchestrator does not apply QA **Proposed spec updates** until **`Task(scrum)`** **PROCEED**), no nested **`Task(spec-validator)`** / **`Task(security-scanner)`** from **`Task(qa)`**, Finish **§ 9** MR safety (no mutating GitLab/GitHub API calls from the orchestrator), and the **git-gitlab-mutations** push/MR rules.

**CI runs automatically on every PR and on pushes to `main`** (`.github/workflows/ci.yml`). It validates:
- Shell syntax and executable bits for `agentic/hooks/*.sh`, `agentic/adapters/*/hooks/*.sh`, and `scripts/`
- All agent and skill files have valid YAML frontmatter with required fields (`agent-validation`, `skill-validation`)
- All JSON files parse correctly (`.mcp.json`, `agentic/adapters/cursor/hooks.json`, `agentic/adapters/claude/settings.json`)
- Every hook script is registered in `agentic/adapters/cursor/hooks.json` and vice versa (bidirectional sync, by basename — `.cursor/` itself is generated and never exists in a CI checkout)
- No `.env` files or obvious secrets are committed
- Documentation was updated when framework files changed (warning, non-blocking)
- Full workspace **`./scripts/tools/lint-check.sh .`** (same command as local runs — see **Agent/Skill Prompt Lint Guards** below)

No hardcoded counts — validation is relationship-based. Add a new agent, skill, hook, or script and the pipeline validates it has valid structure and is properly registered. No manual count updates needed.

If the pipeline fails, fix the issue before requesting review. Documentation warnings are non-blocking but should be addressed.

## Agent/Skill Prompt Lint Guards

**Enforcement:** From the repository root, run **`./scripts/tools/lint-check.sh .`**. The script (1) scans **`agentic/agents/*.md`** for disallowed MCP toolbox patterns—**`Optional MCP`**, **`call_mcp_tool`**, and **`MCP server`** / **`MCP servers`** (case-insensitive)—in every file **except** allowlisted **`mcp-*.md`**, **`plan.md`**, and **`pre-plan-triage.md`**; (2) scans **`agentic/agents/*.md`** and **`agentic/skills/**/*.md`** for instructional shell one-liners (**`python3 -c`**, **`git mv`**, **`git commit`**, **`awk '{`**) outside markdown fences, with exemptions for prohibition wording, first-party script references (**`pipeline-finish`**, **`pipeline-commit`**, **`git-inspect.sh`**, **`query-transcript.py`**, **`audit-session-trace`**), and lines marked with **`<!-- lint:allow-subagent-shell -->`**. Details: **`scripts/tools/lint-check.sh`** header and **`scripts/tools/lint-subagent-prompt-patterns.py`**. For the subagent shell guard, **`./scripts/tools/tests/test-lint-check-subagent-shell-patterns.sh`** (see **`scripts/tools/tests/README.md`**). To confirm the MCP guard manually, temporarily add a line containing **`Optional MCP`** to a non-allowlisted agent (e.g. **`dev.md`**), run **`./scripts/tools/lint-check.sh .`**, expect failure, then revert.

## Conventions

### Specs (ticket folders)

Architecture/product specs live under **`docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/`** as three
separate files — **`prd.md`**, **`spectech.md`**, **`tasks.md`** — plus the control files
**`_state.json`** and **`_notes.md`**. There is **no** single-file `*-spec.md` convention in this
repo anymore; see **`agentic/AGENTS.md`** — **Spec Format (ticket-folder contract)** for the full
schema. (`agentic/skills/generate-spec/SKILL.md` is retained only as a reference for
`plan-reviewer.md`'s legacy single-file-mode completeness check — nothing in this repo produces a
`*-spec.md` file anymore.)

### Subagents

- YAML frontmatter: `name`, `description`, `model` (canonical value is `inherit` — see **Model Selection** in `agentic/adapters/claude/CLAUDE.md` / `00-workspace-router.mdc`), optionally `readonly`
- **8 sections** for persona subagents: Role, Trigger & Input, Toolbox, Workflow, Spec Interaction, Completion Output, Error Handling, Guardrails
- `description` **must** include the substring **Use when** (case-insensitive; enforced by `lint-workspace-agents.sh` in CI)

### Supporting Subagents (dual-mode)

- YAML frontmatter: `model: inherit` (or a specific ID); `readonly: true`
- Simpler structure: Name, Description, Toolbox, Structured Output
- Descriptions should include "Use when..."
- **Pre-plan specialists** (the 5 generic domain specialists, `repro-specialist`, `pre-plan-triage`, and the optional enterprise `mcp-glean` / `mcp-confluence` / `mcp-jira` / `mcp-gitlab`) are **read-only** and are delegated from the **main session** during **`/run`** pre-plan (see **`agentic/skills/run-pipeline/SKILL.md`**), not nested inside **`Task(prd)`** — avoids duplicate gather; **`00-workspace-router.mdc`** and **`agentic/AGENTS.md`** list triggers and boundaries.

### Per-Persona Reviewers

- Common output format: Score, Findings table, Confidence Factors, Verdict, Rework Instructions
- Must define domain-specific confidence factors with score/100

### Skills

- `SKILL.md` under a descriptive directory in `agentic/skills/`; YAML frontmatter with `name` and `description`
- Use `references/` for progressive disclosure

### Scripts

- `#!/usr/bin/env bash`, executable, `--help` flag, auto-detect tech stack
- Descriptive header comment explaining purpose (2-4 lines after shebang)

### Hooks

- `#!/usr/bin/env bash`, executable, read JSON from stdin, return JSON to stdout
- Descriptive header comment explaining purpose, inputs, and behavior
- Shared scripts in `agentic/hooks/`, IDE-specific overlays in `agentic/adapters/<ide>/hooks/`; config in `agentic/adapters/claude/settings.json` (Claude) and `agentic/adapters/cursor/hooks.json` (Cursor)

## Adding a New Persona

1. Create `agentic/agents/name.md` (all 8 sections, valid frontmatter with name/description/model)
2. Optionally create `agentic/agents/name-reviewer.md`
3. Optionally create `agentic/skills/name-related-skill/SKILL.md`
4. Update `agentic/adapters/cursor/rules/00-workspace-router.mdc` to list the new trigger
5. If a reviewer was added: update `agentic/skills/run-pipeline/SKILL.md` (and the router if needed) so orchestrated mode delegates to it
6. Update `README.md` persona table
7. Run `./scripts/setup.sh` to validate (no count updates needed — validation is automatic)

**Note:** No trigger rule is needed for Cursor — it natively routes `/name` once installed. No hardcoded counts to update — `setup.sh` and CI validate structure and relationships dynamically.
