# Workspace linter checks

These scripts validate **committed** paths only (`docs/specs/*-spec.md`, `.cursor/agents/*.md`). There are no isolated fixture directories wired into the linters.

## Automated smoke check

From the repository root:

```bash
./scripts/tools/tests/run-workspace-linter-selftest.sh
```

This runs `./scripts/tools/lint-workspace-content.sh` and is suitable before an MR when you changed specs or agents.

## lint-check.sh ROAD guard (permanent prompts)

`scripts/tools/lint-check.sh` rejects `ROAD-<digits>` under `.cursor/agents/`, `.cursor/skills/`, and `.cursor/rules/` (see **CONTRIBUTING.md** — *No Historical Tracking IDs in Prompts*).

**Self-check** (clean tree must pass; negative case uses a temporary directory):

```bash
./scripts/tools/tests/test-lint-check-road-guard.sh
```

**Manual:** From the repo root after edits to rules, skills, or agents, run `./scripts/tools/lint-check.sh .` and confirm exit code 0.

## lint-check.sh subagent shell patterns (ROAD-55)

`scripts/tools/lint-check.sh` rejects forbidden instructional substrings in **`.cursor/agents/*.md`** and **`.cursor/skills/**/*.md`** (see **CONTRIBUTING.md** — *No Historical Tracking IDs* section for full `lint-check.sh` behavior).

**Self-check** (clean isolated tree passes; negative case uses a temporary directory):

```bash
./scripts/tools/tests/test-lint-check-subagent-shell-patterns.sh
```

## Roadmap tools self-test

```bash
./scripts/tools/tests/roadmap-tools-selftest.sh
```

Covers `roadmap-next.sh` and `roadmap-validate.sh` against fixtures under `scripts/tools/tests/fixtures/`.

## sync-roadmap-status (ROAD-45)

```bash
./scripts/tools/tests/test-sync-roadmap-status.sh
```

Uses a temporary git repo with `docs/specs/` and `docs/roadmaps/` to exercise `--dry-run` and a real sync (status line + `git mv` into `completed/`).

**lint-check status-sync (ROAD-45):** `./scripts/tools/tests/test-lint-check-roadmap-spec-sync.sh`

## apply-models self-test

Non-destructive fixture test (uses `APPLY_MODELS_ROOT`):

```bash
./scripts/tools/tests/apply-models-manual-mode-selftest.sh
```

## MR description from spec

```bash
./scripts/tools/tests/mr-description-selftest.sh
```

Covers `mr-description-from-spec.sh` against `scripts/tools/tests/fixtures/mr-spec-sample.md`.

## Cursor project hash + session trace anchors

```bash
./scripts/tools/tests/test-cursor-project-hash.sh
```

Covers `cursor-project-hash.sh` encoding and `session-memory.sh write-trace-anchors` (uses a temporary session; backs up `docs/sessions/ACTIVE_SESSION`).

## Session memory append order

```bash
./scripts/tools/tests/test-session-memory-ordering.sh
```

Asserts **`## Timeline`** append-only ordering: trace anchors before gate/context lines, and **`PIPELINE: COMPLETE`** as the last meaningful line after a simulated Finish sequence.

## audit-session-trace

```bash
./scripts/tools/tests/test-audit-session-trace.sh
```

Covers `audit-session-trace.py` against a fake `$HOME/.cursor/projects/<hash>/agent-transcripts/` tree (no dependency on the developer’s real `~/.cursor`).

## Manual negative tests

Because linters target real repo paths, use a **temporary** edit on a branch (or stash), then revert:

1. **Spec linter** — In any `docs/specs/*-spec.md` file: rename the file to break allowed patterns (`YYYY-MM-DD-{slug}-spec.md` or optional `…T…Z-` / `…-HHMM-` affixes per `generate-spec`), drop required frontmatter, reorder `##` sections away from `generate-spec`, or add an invalid task tag outside `[dev|sre|data]` (with optional `:repo`). Run `./scripts/tools/lint-workspace-specs.sh`; expect exit 1 and `FAIL` lines.
2. **Agent linter** — In any `.cursor/agents/*.md` file: remove “Use when” from `description`, or drop a required frontmatter key. Run `./scripts/tools/lint-workspace-agents.sh`; expect exit 1.

Restore the file(s) before committing.
