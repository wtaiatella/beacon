# Workspace linter checks

These scripts validate **committed** paths only (`agentic/agents/*.md`, `agentic/skills/**/*.md`). There are no isolated fixture directories wired into the linters.

## Automated smoke check

From the repository root:

```bash
./scripts/tools/tests/run-workspace-linter-selftest.sh
```

This runs `./scripts/tools/lint-workspace-agents.sh` and is suitable before an MR when you changed agents.

## lint-check.sh subagent shell patterns (ROAD-55)

`scripts/tools/lint-check.sh` rejects forbidden instructional substrings in **`agentic/agents/*.md`** and **`agentic/skills/**/*.md`** (see **CONTRIBUTING.md** — *No Historical Tracking IDs* section for full `lint-check.sh` behavior).

**Self-check** (clean isolated tree passes; negative case uses a temporary directory):

```bash
./scripts/tools/tests/test-lint-check-subagent-shell-patterns.sh
```

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

Covers `cursor-project-hash.sh` encoding and `session-memory.sh write-trace-anchors` (uses a temporary ticket folder under `docs/specs/`).

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

1. **Agent linter** — In any `agentic/agents/*.md` file: remove “Use when” from `description`, or drop a required frontmatter key. Run `./scripts/tools/lint-workspace-agents.sh`; expect exit 1.

Restore the file(s) before committing.
