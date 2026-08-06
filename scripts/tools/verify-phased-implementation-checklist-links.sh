#!/usr/bin/env bash
# Docs-only CI: ensure phased implementation manual checklist exists, cites key repo paths, and
# markdown links (if any) resolve to tracked files/dirs. Gitignored session files
# are referenced in prose only — not required on disk.
# Run from repo root: ./scripts/tools/verify-phased-implementation-checklist-links.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CHECKLIST="scripts/tools/verify-phased-implementation-checklist.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "verify-phased-implementation-checklist-links: repo root=$ROOT"

test -f "$CHECKLIST" || fail "missing $CHECKLIST"

# --- Required prose references (procedure + session layout) ---
grep -q 'docs/sessions/ACTIVE_SESSION' "$CHECKLIST" \
  || fail "checklist must mention docs/sessions/ACTIVE_SESSION"
grep -q 'docs/specs' "$CHECKLIST" \
  || fail "checklist must mention docs/specs"

# --- Tracked files the checklist must cite; must exist in clone ---
REFS=(
  ".cursor/skills/run-pipeline/SKILL.md"
  ".cursor/rules/00-workspace-router.mdc"
  "docs/run-pipeline-reference.md"
  "docs/reference/nested-task-audit.md"
)
for p in "${REFS[@]}"; do
  test -f "$p" || fail "missing tracked file: $p"
  grep -Fq "$p" "$CHECKLIST" || fail "checklist must reference $p"
done

# --- Markdown [text](relative-path) links: validate targets if present ---
# (Checklist may use backticks only; this keeps CI useful if links are added later.)
while IFS= read -r raw; do
  url="${raw#](}"
  url="${url%)}"
  url="${url%%#*}"
  case "$url" in
    ''|http://*|https://*|mailto:*|ftp://*) continue ;;
  esac
  case "$url" in
    //*) continue ;;
  esac
  case "$url" in
    *..*) fail "markdown link must not use parent segments: $url" ;;
  esac
  if [ -e "$url" ]; then
    echo "OK link target: $url"
  else
    fail "broken markdown link target in checklist: $url"
  fi
done < <(grep -oE '\]\([^)]+\)' "$CHECKLIST" 2>/dev/null || true)

echo "OK: phased implementation checklist doc checks passed"
