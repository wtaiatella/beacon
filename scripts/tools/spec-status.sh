#!/usr/bin/env bash
# List all specs in docs/specs/ with their lifecycle status, task progress, and dates.
# Used by session-init hook and /scrum for spec discovery.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPECS="$ROOT/docs/specs"

usage() {
  echo "Usage: $(basename "$0")"
  echo "  Lists spec files under docs/specs/ with frontmatter and task progress."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$SPECS" ]] || ! ls "$SPECS"/*.md >/dev/null 2>&1; then
  echo "No specs found. Use /plan to create one."
  exit 0
fi

parse_frontmatter() {
  local f=$1
  awk '
    /^---$/ { if (++n == 1) next; if (n == 2) exit }
    n == 1 {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^status:[[:space:]]*/) { sub(/^status:[[:space:]]*/, "", line); gsub(/^["'\'']|["'\'']$/, "", line); print "status=" line; next }
      if (line ~ /^created:[[:space:]]*/) { sub(/^created:[[:space:]]*/, "", line); gsub(/^["'\'']|["'\'']$/, "", line); print "created=" line; next }
      if (line ~ /^last-updated:[[:space:]]*|^last updated:[[:space:]]*/) {
        sub(/^last-updated:[[:space:]]*|^last updated:[[:space:]]*/, "", line)
        gsub(/^["'\'']|["'\'']$/, "", line)
        print "last-updated=" line
      }
    }
  ' "$f" 2>/dev/null
}

sep=$(printf '%.0s-' {1..120})
printf "%-36s | %-14s | %-12s | %-14s | %s\n" "Filename" "Status" "Created" "Last Updated" "Task Progress"
printf "%s\n" "$sep"

for f in "$SPECS"/*.md; do
  [[ -f "$f" ]] || continue
  base=$(basename "$f")
  status="-"; created="-"; updated="-"
  while IFS= read -r line; do
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      status) status="$val" ;;
      created) created="$val" ;;
      last-updated) updated="$val" ;;
    esac
  done < <(parse_frontmatter "$f")
  x=$(grep -c '\[x\]' "$f" 2>/dev/null || true)
  sp=$(grep -c '\[ \]' "$f" 2>/dev/null || true)
  tot=$((x + sp))
  prog="${x}/${tot}"
  [[ "$tot" -eq 0 ]] && prog="0/0"
  printf "%-36s | %-14s | %-12s | %-14s | %s\n" "$base" "$status" "$created" "$updated" "$prog"
done
