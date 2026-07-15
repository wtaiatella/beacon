#!/usr/bin/env bash
# ROAD-55: lint-check.sh subagent shell guard — clean isolated tree passes; forbidden substring fails.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LINT="$ROOT/scripts/tools/lint-check.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/clean/.cursor/agents" "$TMP/clean/.cursor/skills/sample"
printf '%s\n' '# Fixture' >"$TMP/clean/.cursor/agents/dev.md"
printf '%s\n' '# Fixture' >"$TMP/clean/.cursor/skills/sample/SKILL.md"

echo "── lint-check.sh subagent shell guard: clean isolated tree ──"
"$LINT" "$TMP/clean"
echo "OK clean tree passes"

mkdir -p "$TMP/bad/.cursor/agents"
# Intentional violation: instructional inline python3 -c outside fences / exemptions.
printf '%s\n' 'Use python3 -c "import json" to parse transcripts.' >"$TMP/bad/.cursor/agents/bad-fixture.md"

echo "── lint-check.sh subagent shell guard: expect failure on fixture ──"
set +e
"$LINT" "$TMP/bad"
st=$?
set -e
if [[ "$st" -eq 0 ]]; then
  echo "FAIL: expected non-zero exit when agent file contains forbidden subagent shell pattern" >&2
  exit 1
fi
echo "OK fixture correctly failed lint-check"
