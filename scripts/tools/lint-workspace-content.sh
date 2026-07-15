#!/usr/bin/env bash
# Run both workspace content linters (specs + agents). Exits 0 when both pass.
# Intended for local checks and CI self-test of workspace content linters.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
"$ROOT/scripts/tools/lint-workspace-specs.sh"
"$ROOT/scripts/tools/lint-workspace-agents.sh"
echo "OK Workspace content linters passed"
