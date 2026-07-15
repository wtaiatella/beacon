#!/usr/bin/env bash
# Smoke test: run workspace content linters (specs + agents). Exit non-zero if either fails.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$ROOT/scripts/tools/lint-workspace-content.sh"
