#!/usr/bin/env bash
#
# Optional warnings-only scan for nested-delegation regression phrases in agentic/agents.
# lint-workspace-agents.sh validates frontmatter only — this script does not duplicate that.
#
# Behavior: print WARN lines if historical nested-risk wording reappears; always exit 0 (CI non-blocking).
#
# Usage: ./scripts/tools/check-nested-task-docs.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$ROOT/agentic/agents"

echo "── Nested Task doc regression check (warnings-only) ──"

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "OK No $AGENTS_DIR"
  exit 0
fi

WARN=0
shopt -s nullglob
for f in "$AGENTS_DIR"/*.md; do
  rel=${f#"$ROOT/"}
  # Phrases removed during nested-Task remediation; reintroduction suggests nested-delegation wording drift.
  if grep -qiE 'sub-delegate|parallel sub-delegation' "$f" 2>/dev/null; then
    echo "WARN $rel -- contains Sub-delegate / Parallel sub-delegation phrasing (review for nested Task instructions)"
    WARN=1
  fi
  if grep -qiE 'delegate[[:space:]]+to[[:space:]]+`codebase-explorer`|delegate[[:space:]]+to[[:space:]]+codebase-explorer' "$f" 2>/dev/null; then
    echo "WARN $rel -- contains Delegate to codebase-explorer phrasing (review for persona-owned Task)"
    WARN=1
  fi
done

if [[ "$WARN" -eq 0 ]]; then
  echo "OK No nested-delegation regression phrases in agentic/agents/"
fi
exit 0
