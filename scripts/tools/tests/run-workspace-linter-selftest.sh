#!/usr/bin/env bash
# Smoke test: run the workspace agent content linter. Exit non-zero if it fails.
# (The old single-file spec linter was retired — docs/specs/ is folder-mode
# prd.md+spectech.md+tasks.md now, not a *-spec.md file; see AGENTS.md — Spec Format.)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$ROOT/scripts/tools/lint-workspace-agents.sh"
