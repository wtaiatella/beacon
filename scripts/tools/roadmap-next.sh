#!/usr/bin/env bash
# Print the next ROAD-NN id for a roadmap tree (max ROAD-NN from filenames + 1).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=roadmap-lib.sh
source "$(dirname "$0")/roadmap-lib.sh"

usage() {
  echo "Usage: $(basename "$0") [--file <dir> | --root <dir>] [--print ROAD|NUMBER]"
  echo "  --file <dir>    Roadmap root directory (default: \$ROADMAP_FILE or docs/roadmaps under repo root)"
  echo "  --root <dir>    Same as --file (alias)"
  echo "  --print ROAD    Print 'ROAD-NN' (default)"
  echo "  --print NUMBER  Print numeric id only"
  echo ""
  echo "Environment: ROADMAP_FILE — roadmap root directory (relative to repo root or absolute)."
  echo "  Scans ROAD-<n>-*.md in the root and in completed/; next id is max(n)+1."
}

FILE=""
PRINT="ROAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file | --root)
      FILE="${2:?}"
      shift 2
      ;;
    --print)
      PRINT="${2:?}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FILE" ]]; then
  FILE="$(roadmap_default_root "$ROOT")"
elif [[ "${FILE}" != /* ]]; then
  FILE="${ROOT%/}/${FILE}"
fi

if [[ -f "$FILE" ]]; then
  echo "Error: roadmap path must be a directory (roadmap root), not a single file: $FILE" >&2
  echo "Set ROADMAP_FILE or --file/--root to the directory containing ROAD-NN-*.md (e.g. docs/roadmaps)." >&2
  exit 1
fi

if [[ ! -d "$FILE" ]]; then
  echo "Error: roadmap root not found: $FILE" >&2
  exit 1
fi

next=$(roadmap_next_id "$FILE")
case "$PRINT" in
  ROAD) echo "ROAD-${next}" ;;
  NUMBER) echo "${next}" ;;
  *)
    echo "Error: --print must be ROAD or NUMBER" >&2
    exit 1
    ;;
esac
