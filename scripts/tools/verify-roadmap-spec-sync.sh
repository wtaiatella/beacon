#!/usr/bin/env bash
# Exit 0 when every docs/specs/*-spec.md with status: completed has a matching
# ROAD-NN roadmap that is archived under completed/ with **Status:** Completed.
# Exit 1 on drift: active roadmap still Planned/In-Progress, still in active root
# with Completed label (not moved), duplicate active+completed, or multiple active files.
#
# Association: ROAD id from basename -road-<digits>- (ROAD-45). Specs without that
# segment are skipped (warning only).
#
# Environment: ROADMAP_FILE — roadmap tree root (same as roadmap-validate.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=roadmap-lib.sh
source "$SCRIPT_DIR/roadmap-lib.sh"

REPO_ROOT=""
SPECS_DIR=""
ROADMAP_ROOT_OVERRIDE=""

usage() {
  echo "Usage: $(basename "$0") [--root <repo-dir>] [--specs-dir <dir>] [--roadmap-root <dir>]"
  echo "  Verifies roadmap/spec alignment for completed specs. Non-zero on violation."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      REPO_ROOT="${2:?}"
      shift 2
      ;;
    --specs-dir)
      SPECS_DIR="${2:?}"
      shift 2
      ;;
    --roadmap-root)
      ROADMAP_ROOT_OVERRIDE="${2:?}"
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

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

if [[ -z "$SPECS_DIR" ]]; then
  SPECS_DIR="$REPO_ROOT/docs/specs"
else
  SPECS_DIR="$(cd "$SPECS_DIR" && pwd)"
fi

if [[ -n "$ROADMAP_ROOT_OVERRIDE" ]]; then
  ROAD_ROOT="$(cd "$ROADMAP_ROOT_OVERRIDE" && pwd)"
else
  ROAD_ROOT="$(roadmap_default_root "$REPO_ROOT")"
  if [[ "${ROAD_ROOT}" != /* ]]; then
    ROAD_ROOT="${REPO_ROOT%/}/${ROAD_ROOT}"
  fi
  ROAD_ROOT="$(cd "$ROAD_ROOT" && pwd)"
fi

if [[ ! -d "$SPECS_DIR" ]] || [[ ! -d "$ROAD_ROOT" ]]; then
  echo "verify-roadmap-spec-sync: skip (missing specs dir or roadmap root)" >&2
  exit 0
fi

# Frontmatter status — aligned with sync-roadmap-status.sh / spec-status.sh
parse_spec_status() {
  local f=$1
  awk '
    /^---$/ { if (++n == 1) next; if (n == 2) exit }
    n == 1 {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^status:[[:space:]]*/) {
        sub(/^status:[[:space:]]*/, "", line)
        gsub(/^["'\'']|["'\'']$/, "", line)
        print tolower(line)
        exit
      }
    }
  ' "$f" 2>/dev/null
}

spec_road_id_from_basename() {
  local base="$1"
  if [[ "$base" =~ -road-([0-9]+)- ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# First **Status:** line value (trimmed), or empty if missing
roadmap_status_value() {
  python3 - "$1" <<'PY'
import re, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^\*\*Status:\*\*\s*(.*)$", line)
            if m:
                print(m.group(1).strip())
                sys.exit(0)
except OSError:
    print("", end="")
    sys.exit(1)
sys.exit(1)
PY
}

# True if roadmap **Status:** value starts with Completed (allows suffixes like dates).
is_status_completed() {
  python3 -c 'import re,sys; s=sys.argv[1].strip(); sys.exit(0 if re.match(r"(?i)completed\b", s) else 1)' "$1"
}

violations=0

record_violation() {
  echo "Error: $*" >&2
  violations=1
}

shopt -s nullglob
for spec in "$SPECS_DIR"/*.md; do
  [[ -f "$spec" ]] || continue
  base=$(basename "$spec")
  st=$(parse_spec_status "$spec")
  if [[ "$st" != "completed" ]]; then
    continue
  fi

  rid=""
  if ! rid=$(spec_road_id_from_basename "$base"); then
    echo "WARN: spec has status completed but filename has no -road-<n>- segment: $base (skipped)" >&2
    continue
  fi

  active_matches=()
  for f in "$ROAD_ROOT"/ROAD-"${rid}"-*.md; do
    [[ -f "$f" ]] && active_matches+=("$f")
  done
  completed_matches=()
  if [[ -d "$ROAD_ROOT/completed" ]]; then
    for f in "$ROAD_ROOT"/completed/ROAD-"${rid}"-*.md; do
      [[ -f "$f" ]] && completed_matches+=("$f")
    done
  fi

  an=${#active_matches[@]}
  cn=${#completed_matches[@]}

  if [[ "$an" -eq 0 ]]; then
    if [[ "$cn" -ge 1 ]]; then
      cf="${completed_matches[0]}"
      cv=$(roadmap_status_value "$cf")
      if ! is_status_completed "$cv"; then
        record_violation "ROAD-$rid: spec $base is completed but archived roadmap $(basename "$cf") has Status: ${cv:-<missing>} (expected Completed)."
      fi
    else
      echo "WARN: no ROAD-${rid}-*.md under $ROAD_ROOT for completed spec $base (skipped)" >&2
    fi
    continue
  fi

  if [[ "$an" -gt 1 ]]; then
    record_violation "ROAD-$rid: multiple active ROAD-${rid}-*.md files while spec $base is completed; resolve manually."
    continue
  fi

  active_file="${active_matches[0]}"

  if [[ "$cn" -ge 1 ]]; then
    record_violation "ROAD-$rid: roadmap exists in both active root and completed/ while spec $base is completed; resolve duplicate."
    continue
  fi

  av=$(roadmap_status_value "$active_file")
  if ! is_status_completed "$av"; then
    record_violation "ROAD-$rid: spec $base is completed but active roadmap $(basename "$active_file") has Status: ${av:-<missing>} (Planned/In-Progress or not Completed — sync roadmap or archive)."
    continue
  fi

  # Status says Completed but file still in active tree (should live under completed/)
  record_violation "ROAD-$rid: spec $base is completed but roadmap $(basename "$active_file") is still in the active roadmap root (Status Completed); move to completed/ (see sync-roadmap-status.sh)."
done

shopt -u nullglob

exit "$violations"
