#!/usr/bin/env bash
#
# Agent file validation: YAML frontmatter + description must include "Use when"
# Agent content lint. Required keys match .gitlab-ci.yml agent-validation (name, description, model).
#
# Requirements: Bash 3.2+. For multi-line YAML in frontmatter, Ruby (stdlib YAML) is used
# when available; otherwise a line-oriented fallback is used (single-line descriptions).
#
# Exit codes:
#   0  All agent files passed (or no .md files under .cursor/agents/).
#   1  One or more validation failures.
#
# Usage: lint-workspace-agents.sh [--help|-h]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$ROOT/.cursor/agents"
FAIL=0

usage() {
  echo "Usage: $(basename "$0")"
  echo "  Validates .cursor/agents/*.md frontmatter (name, description, model) and"
  echo "  requires case-insensitive \"Use when\" in description (see workspace router)."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "── Agent Content Lint ──"

# Extract YAML between first two --- lines (same as agent-validation); no line cap so
# multi-line values are not truncated.
extract_frontmatter_body() {
  sed -n '/^---$/,/^---$/p' "$1" | sed '1d;$d'
}

# Description text for "Use when" check: prefer Ruby YAML for multi-line safety.
description_text() {
  local body desc
  body=$(extract_frontmatter_body "$1")
  if [[ -z "${body// }" ]]; then
    printf ''
    return 0
  fi
  if command -v ruby >/dev/null 2>&1; then
    if desc=$(printf '%s\n' "$body" | ruby -ryaml -e '
      begin
        y = YAML.load($stdin.read)
        if y.is_a?(Hash)
          print y["description"].to_s
        else
          exit 1
        end
      rescue StandardError
        exit 1
      end
    ' 2>/dev/null); then
      printf '%s' "$desc"
      return 0
    fi
  fi
  # Fallback: single-line description or simple literal block (no Ruby / parse error)
  awk '
    /^description:/ {
      sub(/^description:[[:space:]]+/, "")
      if ($0 ~ /^\|[+-]?[[:space:]]*$/ || $0 ~ /^>[+-]?[[:space:]]*$/) {
        while (getline > 0) {
          if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_-]*:[[:space:]]/ && $0 !~ /^[[:space:]]/) exit
          print
        }
        exit
      }
      print
      exit
    }
  ' <<< "$body"
}

shopt -s nullglob
AGENT_FILES=("$AGENTS_DIR"/*.md)

if [[ ${#AGENT_FILES[@]} -eq 0 ]]; then
  echo "OK No agent files under .cursor/agents/ (nothing to validate)"
  exit 0
fi

for f in "${AGENT_FILES[@]}"; do
  BASENAME=$(basename "$f")
  DASHES=$(grep -c '^---$' "$f" || true)
  if [[ "$DASHES" -lt 2 ]]; then
    echo "FAIL $BASENAME -- missing YAML frontmatter"
    FAIL=1
    continue
  fi
  FM_BODY=$(extract_frontmatter_body "$f")
  if [[ -z "${FM_BODY// }" ]]; then
    echo "FAIL $BASENAME -- empty YAML frontmatter body"
    FAIL=1
    continue
  fi
  echo "$FM_BODY" | grep -q '^name:' || { echo "FAIL $BASENAME -- missing name"; FAIL=1; continue; }
  echo "$FM_BODY" | grep -q '^description:' || { echo "FAIL $BASENAME -- missing description"; FAIL=1; continue; }
  echo "$FM_BODY" | grep -q '^model:' || { echo "FAIL $BASENAME -- missing model"; FAIL=1; continue; }

  DESC_TEXT=$(description_text "$f" || true)
  if printf '%s' "$DESC_TEXT" | grep -qiF 'Use when'; then
    echo "OK $BASENAME"
  else
    echo "FAIL $BASENAME -- description must include \"Use when\" (see agent conventions)"
    FAIL=1
  fi
done

TOTAL=$(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
echo "Total agents: $TOTAL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "OK All agents passed content lint"
