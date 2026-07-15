#!/usr/bin/env bash
# Self-test for mr-description-from-spec.sh (fixture under fixtures/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TOOL="$ROOT/scripts/tools/mr-description-from-spec.sh"
FIX="$ROOT/scripts/tools/tests/fixtures/mr-spec-sample.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "── mr-description-from-spec self-test ──"

[[ -x "$TOOL" ]] || chmod +x "$TOOL" 2>/dev/null || true

out="$("$TOOL" "$FIX")"
echo "$out" | grep -q 'Sample spec for MR template fixture' || fail "missing title line"
echo "$out" | grep -q '## Tasks' || fail "missing Tasks section"
echo "$out" | grep -q 'Implement widget A' || fail "missing dev task line"
echo "$out" | grep -q '## Acceptance criteria' || fail "missing Acceptance section"
echo "$out" | grep -q 'Widget works' || fail "missing acceptance bullet"
echo "$out" | grep -q 'scripts/tools/tests/fixtures/mr-spec-sample.md' || fail "missing spec path"
echo "$out" | grep -q 'Suggested GitLab labels' || fail "missing labels section"
echo "$out" | grep -q '`dev, sre`' || fail "missing label hint"

echo "OK mr-description-from-spec"
