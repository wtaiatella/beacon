#!/usr/bin/env bash
# Tests for roadmap-next.sh and roadmap-validate.sh (fixtures under scripts/tools/tests/fixtures/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NEXT="$ROOT/scripts/tools/roadmap-next.sh"
VAL="$ROOT/scripts/tools/roadmap-validate.sh"
FIX="$ROOT/scripts/tools/tests/fixtures"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "── roadmap tools self-test ──"

# next id from filenames: canonical roadmap-prefix files in directory fixture (mirrors roadmap-good.md semantics)
out="$(ROADMAP_FILE="scripts/tools/tests/fixtures/roadmap-good-dir" "$NEXT" --print NUMBER)"
[[ "$out" == "2" ]] || fail "roadmap-next expected 2, got $out"

out="$("$NEXT" --file "$FIX/roadmap-good-dir" --print NUMBER)"
[[ "$out" == "2" ]] || fail "roadmap-next --file dir expected 2, got $out"

out="$("$NEXT" --root "$FIX/roadmap-good-dir" --print ROAD)"
[[ "$out" == "ROAD-2" ]] || fail "roadmap-next --root expected ROAD-2, got $out"

out="$("$NEXT" --file "$FIX/roadmap-next-mixed" --print NUMBER)"
[[ "$out" == "16" ]] || fail "roadmap-next mixed active+completed expected 16, got $out"

# validate: directory root (active + completed/)
"$VAL" --file "$FIX/roadmap-good-dir" --quiet || fail "validate good-dir should exit 0"
"$VAL" --root "$FIX/roadmap-good-dir" --quiet || fail "validate --root good-dir should exit 0"
"$VAL" --file "$FIX/roadmap-validate-cross-dir" --quiet || fail "validate cross-tree deps (union) should exit 0"

# monolithic .md path must be rejected (ROADMAP_FILE / --file = directory)
if "$VAL" --file "$FIX/roadmap-good.md" --quiet 2>/dev/null; then
  fail "validate should reject single-file path"
fi

# directory-mode: same semantics as legacy single-file fixtures (split into dirs)
if "$VAL" --file "$FIX/roadmap-validate-cycle-dir" --quiet 2>/dev/null; then
  fail "validate cycle-dir should exit non-zero"
fi

if "$VAL" --file "$FIX/roadmap-validate-orphan-dir" --quiet 2>/dev/null; then
  fail "validate orphan-dir should exit non-zero"
fi

if "$VAL" --file "$FIX/roadmap-validate-dup-dir" --quiet 2>/dev/null; then
  fail "validate duplicate-dir should exit non-zero"
fi

# External path via ROADMAP_FILE (relative to ROOT): directory root
pushd "$ROOT" >/dev/null
export ROADMAP_FILE="scripts/tools/tests/fixtures/roadmap-good-dir"
[[ "$("$NEXT" --print NUMBER)" == "2" ]] || fail "ROADMAP_FILE relative dir broken"
"$VAL" --quiet || fail "ROADMAP_FILE relative dir: validate default should exit 0"
unset ROADMAP_FILE
popd >/dev/null

# Single .md path must error (directory-only contract)
if ROADMAP_FILE="scripts/tools/tests/fixtures/roadmap-good.md" "$NEXT" --print NUMBER 2>/dev/null; then
  fail "roadmap-next should reject ROADMAP_FILE pointing at a file"
fi

if ROADMAP_FILE="scripts/tools/tests/fixtures/roadmap-good.md" "$VAL" --quiet 2>/dev/null; then
  fail "roadmap-validate should reject ROADMAP_FILE pointing at a file"
fi

echo "OK roadmap-next + roadmap-validate fixtures"
