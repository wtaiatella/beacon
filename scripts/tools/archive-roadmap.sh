#!/usr/bin/env bash
# Move one ROAD-NN-*.md from the active roadmap tree into completed/ using git mv (staged).
# Uses roadmap root resolution from roadmap-lib.sh (ROADMAP_FILE / docs/roadmaps).
# Refuses duplicate active+completed entries for the same numeric id (verify-roadmap-spec-sync.sh).
#
# Usage: archive-roadmap.sh [--root <repo>] [--roadmap-root <dir>] [--dry-run] <ROAD-NN|NN>
#        archive-roadmap.sh ... --id ROAD-NN
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=roadmap-lib.sh
source "$SCRIPT_DIR/roadmap-lib.sh"

REPO_ROOT=""
ROADMAP_ROOT_OVERRIDE=""
DRY_RUN=0
ROAD_INPUT=""

usage() {
  echo "Usage: $(basename "$0") [--root <repo-dir>] [--roadmap-root <dir>] [--dry-run] [--id] <ROAD-NN|NN>"
  echo ""
  echo "  Archives a single active ROAD-NN-*.md under the roadmap root into completed/."
  echo "  Requires a git repository (--root) for non-dry-run moves."
  echo ""
  echo "  --root <dir>         Repository root (default: parent of scripts/tools)"
  echo "  --roadmap-root <dir> Roadmap tree root (default: roadmap_default_root(<root>))"
  echo "  --dry-run            Print intended git commands; do not modify files"
  echo "  --id <ROAD-NN|NN>    Roadmap id (optional if given as sole positional)"
  echo ""
  echo "  Environment: ROADMAP_FILE — roadmap root directory when --roadmap-root is omitted"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      REPO_ROOT="${2:?}"
      shift 2
      ;;
    --roadmap-root)
      ROADMAP_ROOT_OVERRIDE="${2:?}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --id)
      ROAD_INPUT="${2:?}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "${ROAD_INPUT:-}" ]]; then
        echo "Error: unexpected extra argument: $1" >&2
        exit 1
      fi
      ROAD_INPUT="$1"
      shift
      ;;
  esac
done

if [[ -z "${ROAD_INPUT:-}" ]]; then
  echo "Error: missing roadmap id (e.g. ROAD-99 or 99)" >&2
  usage >&2
  exit 1
fi

normalize_road_id() {
  local s="$1"
  if [[ "$s" =~ ^[Rr][Oo][Aa][Dd]-([0-9]+)$ ]]; then
    echo $((10#${BASH_REMATCH[1]}))
    return 0
  fi
  if [[ "$s" =~ ^[0-9]+$ ]]; then
    echo $((10#$s))
    return 0
  fi
  echo "Error: invalid roadmap id '$s' (expected ROAD-NN or NN)" >&2
  return 1
}

rid=""
rid=$(normalize_road_id "$ROAD_INPUT") || exit 1

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

if [[ -n "$ROADMAP_ROOT_OVERRIDE" ]]; then
  ROAD_ROOT="$(cd "$ROADMAP_ROOT_OVERRIDE" && pwd)"
else
  ROAD_ROOT="$(roadmap_default_root "$REPO_ROOT")"
  if [[ "${ROAD_ROOT}" != /* ]]; then
    ROAD_ROOT="${REPO_ROOT%/}/${ROAD_ROOT}"
  fi
  ROAD_ROOT="$(cd "$ROAD_ROOT" && pwd)"
fi

if [[ ! -d "$ROAD_ROOT" ]]; then
  echo "Error: roadmap root not found: $ROAD_ROOT" >&2
  exit 1
fi

shopt -s nullglob
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
shopt -u nullglob

an=${#active_matches[@]}
cn=${#completed_matches[@]}

if [[ "$an" -eq 0 ]]; then
  if [[ "$cn" -ge 1 ]]; then
    echo "archive-roadmap: ROAD-${rid} already archived under ${ROAD_ROOT}/completed/ (nothing to do)"
    exit 0
  fi
  echo "Error: no ROAD-${rid}-*.md under $ROAD_ROOT" >&2
  exit 1
fi

if [[ "$an" -gt 1 ]]; then
  echo "Error: multiple active ROAD-${rid}-*.md files; resolve manually before archiving:" >&2
  for f in "${active_matches[@]}"; do
    echo "  $f" >&2
  done
  exit 1
fi

active_file="${active_matches[0]}"
dest_dir="$ROAD_ROOT/completed"
dest_base=$(basename "$active_file")
dest_path="$dest_dir/$dest_base"

if [[ "$cn" -ge 1 ]]; then
  echo "Error: ROAD-${rid} exists in both active root and completed/; remove duplicate before archiving." >&2
  echo "  active:   $active_file" >&2
  echo "  completed: ${completed_matches[0]}" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] roadmap root: $ROAD_ROOT"
  echo "[dry-run] would: git -C \"$REPO_ROOT\" mv -- \"$active_file\" \"$dest_path\""
  echo "[dry-run] would: git -C \"$REPO_ROOT\" add -- \"$dest_path\""
  exit 0
fi

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Error: not a git repository: $REPO_ROOT" >&2
  exit 1
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
  echo "WARN: working tree is not clean; archive will combine with other changes. Consider committing or stashing first." >&2
fi

mkdir -p "$dest_dir"
git -C "$REPO_ROOT" mv -- "$active_file" "$dest_path"
git -C "$REPO_ROOT" add -- "$dest_path"
echo "archive-roadmap: moved ROAD-${rid} to completed/$(basename "$dest_path") (staged)"
exit 0
