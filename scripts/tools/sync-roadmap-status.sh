#!/usr/bin/env bash
# Align roadmap Markdown with completed specs: for each docs/specs/*-spec.md with
# frontmatter status: completed, resolve ROAD-NN from the filename (-road-<digits>- in the slug),
# find ROAD-NN-*.md under the roadmap root; if it exists only in the active tree, set
# **Status:** to Completed and git mv into completed/.
#
# Association rule: ROAD id from basename via pattern -road-<digits>- (see ROAD-45 spec).
# Environment: ROADMAP_FILE — roadmap tree root directory (default docs/roadmaps under --root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=roadmap-lib.sh
source "$SCRIPT_DIR/roadmap-lib.sh"

REPO_ROOT=""
SPECS_DIR=""
ROADMAP_ROOT_OVERRIDE=""
DRY_RUN=0

usage() {
  echo "Usage: $(basename "$0") [--root <repo-dir>] [--specs-dir <dir>] [--roadmap-root <dir>] [--dry-run]"
  echo ""
  echo "  Scans specs for status: completed, resolves ROAD-NN from each filename, and for"
  echo "  matching ROAD-NN-*.md in the active roadmap root (not already under completed/):"
  echo "  updates **Status:** to Completed, then git mv into completed/."
  echo ""
  echo "  --root <dir>       Repository root (default: parent of scripts/tools)"
  echo "  --specs-dir <dir>  Override docs/specs location (default: <root>/docs/specs)"
  echo "  --roadmap-root <dir>  Override roadmap tree (default: roadmap_default_root(<root>))"
  echo "  --dry-run          Print actions only; do not modify files or run git mv"
  echo ""
  echo "  Environment: ROADMAP_FILE — roadmap root if --roadmap-root not set (same as roadmap-validate.sh)."
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
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ ! -d "$SPECS_DIR" ]]; then
  echo "Error: specs directory not found: $SPECS_DIR" >&2
  exit 1
fi
if [[ ! -d "$ROAD_ROOT" ]]; then
  echo "Error: roadmap root not found: $ROAD_ROOT" >&2
  exit 1
fi

# Frontmatter status (first YAML document) — pattern aligned with spec-status.sh
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

# ROAD id from spec basename: ...-road-<digits>-...
spec_road_id_from_basename() {
  local base="$1"
  if [[ "$base" =~ -road-([0-9]+)- ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

update_roadmap_status_line() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    lines = f.readlines()
out = []
done = False
for line in lines:
    if not done and line.startswith("**Status:**"):
        out.append("**Status:** Completed\n")
        done = True
    else:
        out.append(line)
if not done:
    sys.stderr.write(f"WARN: no **Status:** line in {path}; file not changed\n")
    sys.exit(1)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY
}

if [[ "$DRY_RUN" -eq 0 ]] && [[ -d "$REPO_ROOT/.git" ]]; then
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
    echo "WARN: working tree is not clean; sync may combine with other changes. Consider committing or stashing first." >&2
  fi
fi

# One roadmap file per ROAD id per run (multiple specs can reference the same ROAD-NN).
SEEN_ACTIVE=$(mktemp)
trap 'rm -f "${SEEN_ACTIVE:-}"' EXIT

shopt -s nullglob
processed=0
skipped=0

for spec in "$SPECS_DIR"/*.md; do
  [[ -f "$spec" ]] || continue
  base=$(basename "$spec")
  st=$(parse_spec_status "$spec")
  if [[ "$st" != "completed" ]]; then
    continue
  fi
  rid=""
  if ! rid=$(spec_road_id_from_basename "$base"); then
    echo "WARN: spec has status completed but filename has no -road-<n>- segment: $base (skip)" >&2
    ((skipped += 1)) || true
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
      echo "SKIP: ROAD-$rid already archived under completed/ ($base)" >&2
    else
      echo "WARN: no ROAD-${rid}-*.md under $ROAD_ROOT for completed spec $base (skip)" >&2
      ((skipped += 1)) || true
    fi
    continue
  fi

  if [[ "$an" -gt 1 ]]; then
    echo "WARN: multiple active ROAD-${rid}-*.md files; manual resolution required (skip)" >&2
    ((skipped += 1)) || true
    continue
  fi

  active_file="${active_matches[0]}"
  dest_dir="$ROAD_ROOT/completed"
  dest_base=$(basename "$active_file")
  dest_path="$dest_dir/$dest_base"

  if [[ "$cn" -ge 1 ]]; then
    echo "WARN: ROAD-$rid exists in active and completed/; leaving active file in place (skip)" >&2
    ((skipped += 1)) || true
    continue
  fi

  if grep -qxF "$active_file" "$SEEN_ACTIVE" 2>/dev/null; then
    echo "SKIP: ROAD-$rid roadmap already handled for another completed spec ($base)" >&2
    continue
  fi
  printf '%s\n' "$active_file" >> "$SEEN_ACTIVE"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would set **Status:** Completed in: $active_file"
    echo "[dry-run] would: git -C \"$REPO_ROOT\" mv -- \"$active_file\" \"$dest_dir/\""
    ((processed += 1)) || true
    continue
  fi

  if [[ ! -d "$REPO_ROOT/.git" ]]; then
    echo "Error: not a git repository: $REPO_ROOT" >&2
    exit 1
  fi

  update_roadmap_status_line "$active_file" || { ((skipped += 1)) || true; continue; }

  mkdir -p "$dest_dir"
  git -C "$REPO_ROOT" mv -- "$active_file" "$dest_path"
  echo "Synced ROAD-$rid: updated status and moved to completed/$(basename "$dest_path")"
  ((processed += 1)) || true
done

shopt -u nullglob

echo "sync-roadmap-status: roadmap root=$ROAD_ROOT specs=$SPECS_DIR dry-run=$DRY_RUN processed=$processed skipped=$skipped"
exit 0
