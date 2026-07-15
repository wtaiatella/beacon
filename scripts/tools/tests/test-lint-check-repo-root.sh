#!/usr/bin/env bash
# ROAD-53 Phase 2: integration check — scripts/tools/lint-check.sh . from repo root exits 0
# on a clean tree (same invocation as CI workspace-lint-check and CONTRIBUTING.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LINT="$ROOT/scripts/tools/lint-check.sh"

echo "── lint-check.sh: repo root (expect exit 0 on clean tree) ──"
cd "$ROOT"
"$LINT" .
echo "OK lint-check.sh . exited 0 from repo root"
