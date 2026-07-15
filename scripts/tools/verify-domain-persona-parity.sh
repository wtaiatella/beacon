#!/usr/bin/env bash
# Structural diff check (T017): every D0 "no-change" domain-persona/helper file must be
# byte-identical between aw-pp's .claude/ (the parent workspace root that seeded this repo)
# and this repo's (aw-unificado) .claude/. Any non-zero diff is a defect against FR-7
# (spectech Testing Strategy technique 1).
#
# Usage: scripts/tools/verify-domain-persona-parity.sh [--aw-pp-root <path>]
# Default aw-pp root: the parent directory of this repo (aw-unificado is normally cloned as
# a child directory of aw-pp). Override with --aw-pp-root if cloned elsewhere.
set -euo pipefail

DST_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC_ROOT="$(cd "$DST_ROOT/.." && pwd)"

if [ "${1:-}" = "--aw-pp-root" ] && [ -n "${2:-}" ]; then
  SRC_ROOT="$2"
fi

SRC="$SRC_ROOT/.claude/agents"
DST="$DST_ROOT/.claude/agents"

FILES=(
  dev.md
  sre.md
  data.md
  qa.md
  scrum.md
  summary.md
  dev-reviewer.md
  sre-reviewer.md
  data-reviewer.md
  security-scanner.md
  spec-validator.md
  codebase-explorer.md
  plan-reviewer.md
  mcp-arc.md
  mcp-confluence.md
  mcp-gitlab.md
  mcp-glean.md
  mcp-jira.md
)

fail=0
for f in "${FILES[@]}"; do
  if [ ! -f "$SRC/$f" ]; then
    echo "MISSING (source aw-pp): $SRC/$f"
    fail=1
    continue
  fi
  if [ ! -f "$DST/$f" ]; then
    echo "MISSING (destination aw-unificado): $DST/$f"
    fail=1
    continue
  fi
  if diff -q "$SRC/$f" "$DST/$f" >/dev/null 2>&1; then
    echo "OK   $f"
  else
    echo "DIFF $f"
    diff -u "$SRC/$f" "$DST/$f" || true
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "All ${#FILES[@]} domain-persona/helper files are byte-identical (FR-7 verified)."
  exit 0
else
  echo "FR-7 REGRESSION: one or more files differ or are missing. See DIFF/MISSING lines above."
  exit 1
fi
