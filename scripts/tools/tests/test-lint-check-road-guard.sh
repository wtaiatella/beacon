#!/usr/bin/env bash
# Self-check: lint-check.sh ROAD-* guard passes on a clean tree; fails when a .cursor tree contains ROAD-<digits>.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LINT="$ROOT/scripts/tools/lint-check.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Isolated tree without both docs/specs and docs/roadmaps so Status-Sync (ROAD-45) is skipped;
# still exercises ROAD prompt-id and MCP guards on an otherwise empty .cursor/agents.
mkdir -p "$TMP/clean/.cursor/agents"

echo "── lint-check.sh ROAD guard: clean isolated tree ──"
"$LINT" "$TMP/clean"
echo "OK clean tree passes"

mkdir -p "$TMP/bad/.cursor/agents"
echo 'intentional ROAD-999 for negative test' >"$TMP/bad/.cursor/agents/bad-fixture.md"

echo "── lint-check.sh ROAD guard: expect failure on fixture ──"
set +e
"$LINT" "$TMP/bad"
st=$?
set -e
if [[ "$st" -eq 0 ]]; then
  echo "FAIL: expected non-zero exit when .cursor/agents contains ROAD-<digits>" >&2
  exit 1
fi
echo "OK fixture correctly failed lint-check"
