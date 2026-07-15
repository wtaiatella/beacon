#!/usr/bin/env bash
# Generate changelog entries from git history (Keep a Changelog style).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SINCE_REF=""
FORMAT="keep-a-changelog"

usage() {
  cat <<'EOF'
Usage: changelog.sh [options]

  Generate changelog entries from git history (conventional commits).

Options:
  --since <ref>           Start from this ref instead of the latest tag
  --format <name>         Output format (default: keep-a-changelog)
  -h, --help              Show this help

  With no --since: uses the latest tag, or full history if there are no tags.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE_REF="${2:-}"
      if [[ -z "$SINCE_REF" ]]; then echo "error: --since requires a ref" >&2; exit 1; fi
      shift 2
      ;;
    --format)
      FORMAT="${2:-}"
      if [[ -z "$FORMAT" ]]; then echo "error: --format requires a value" >&2; exit 1; fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$FORMAT" != "keep-a-changelog" ]]; then
  echo "error: unsupported format: $FORMAT (only keep-a-changelog is supported)" >&2
  exit 1
fi

if [[ ! -d .git ]]; then
  echo "error: not a git repository (expected .git in $ROOT)" >&2
  exit 1
fi

if [[ -n "$SINCE_REF" ]]; then
  RANGE="${SINCE_REF}..HEAD"
elif tag="$(git describe --tags --abbrev=0 2>/dev/null)"; then
  RANGE="${tag}..HEAD"
else
  RANGE=""
fi

LOG_ARGS=(git log --no-merges --format=$'%h\t%s')
if [[ -n "$RANGE" ]]; then
  LOG_ARGS+=("$RANGE")
fi

categorize() {
  local subject=$1 head type
  case "$subject" in
    *:*)
      head="${subject%%:*}"
      type="${head%%(*}"
      case "$type" in
        feat) echo added ;;
        fix) echo fixed ;;
        docs) echo docs ;;
        refactor) echo changed ;;
        chore) echo maintenance ;;
        perf) echo performance ;;
        *) echo other ;;
      esac
      ;;
    *) echo other ;;
  esac
}

added=() fixed=() docs=() changed=() maintenance=() performance=() other=()

while IFS=$'\t' read -r hash subject; do
  [[ -z "${hash:-}" ]] && continue
  line="- ${subject} (${hash})"
  case "$(categorize "$subject")" in
    added) added+=("$line") ;;
    fixed) fixed+=("$line") ;;
    docs) docs+=("$line") ;;
    changed) changed+=("$line") ;;
    maintenance) maintenance+=("$line") ;;
    performance) performance+=("$line") ;;
    other) other+=("$line") ;;
  esac
done < <("${LOG_ARGS[@]}")

today="$(date +%Y-%m-%d)"
echo "## [Unreleased] - ${today}"
echo ""

emit_section() {
  local title="$1"
  shift
  (($# == 0)) && return 0
  echo "### ${title}"
  local line
  for line in "$@"; do echo "$line"; done
  echo ""
}

emit_section "Added" "${added[@]}"
emit_section "Fixed" "${fixed[@]}"
emit_section "Documentation" "${docs[@]}"
emit_section "Changed" "${changed[@]}"
emit_section "Maintenance" "${maintenance[@]}"
emit_section "Performance" "${performance[@]}"
emit_section "Other" "${other[@]}"
