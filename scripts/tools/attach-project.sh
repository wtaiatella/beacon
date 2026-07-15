#!/usr/bin/env bash
# ROAD-48: Pick a project under PROJECTS_ROOT, write session.code-workspace, open Cursor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
SM="$ROOT/scripts/tools/session-memory.sh"
GEN="$ROOT/scripts/tools/generate-code-workspace.sh"
ENV_LOCAL="$ROOT/.env.local"

usage() {
  cat <<EOF
Usage: attach-project.sh [options]

  Interactive: load \$ROOT/.env.local (if present), ensure PROJECTS_ROOT is set
  (prompt once and persist PROJECTS_ROOT=<absolute> to .env.local), list immediate
  subdirectories of PROJECTS_ROOT with Bash select,   then write:
    docs/sessions/<session-id>/session.code-workspace
    docs/sessions/<session-id>/attach-target.txt   (one line: absolute target root — ROAD-48 trace anchors)
  and launch Cursor on that file.

Session id order (single supported flow):
  1. If docs/sessions/ACTIVE_SESSION exists and names a directory under docs/sessions/<id>/,
     use that <id> (same session as pipeline / hooks).
  2. Otherwise run:  $SM begin-run attach
     to allocate a new session and set ACTIVE_SESSION.

Paths are canonicalized with pwd -P before JSON generation.

Options:
  --no-cursor   Write workspace file only; do not invoke the cursor CLI.
  -h, --help    Show this help.

Environment (from .env.local at orchestrator root):
  PROJECTS_ROOT   Absolute path to a directory whose immediate subdirectories are
                  candidate target repos (optional future keys may be added; see docs/setup.md).

Requires: bash 3.2+, python3 (for JSON), cursor on PATH (unless --no-cursor).
EOF
}

load_env_local() {
  if [ -f "$ENV_LOCAL" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_LOCAL"
    set +a
  fi
}

ensure_projects_root() {
  load_env_local
  local pr="${PROJECTS_ROOT:-}"
  local need_persist=0
  if [ -z "$pr" ]; then
    echo "PROJECTS_ROOT is not set. Enter the absolute path to the directory that contains your project clones:" >&2
    read -r pr
    need_persist=1
    if [ -z "$pr" ]; then
      echo "attach-project: empty path" >&2
      exit 1
    fi
  fi
  if [ ! -d "$pr" ]; then
    echo "attach-project: PROJECTS_ROOT is not a directory: $pr" >&2
    exit 1
  fi
  pr="$(cd "$pr" && pwd -P)"
  if [ "$need_persist" -eq 1 ] || [ ! -f "$ENV_LOCAL" ] || ! grep -qE '^[[:space:]]*PROJECTS_ROOT=' "$ENV_LOCAL" 2>/dev/null; then
    persist_projects_root "$pr"
  else
    PROJECTS_ROOT="$pr"
  fi
}

persist_projects_root() {
  local pr="$1"
  local tmp
  tmp="$(mktemp)"
  if [ -f "$ENV_LOCAL" ]; then
    grep -vE '^[[:space:]]*PROJECTS_ROOT=' "$ENV_LOCAL" >"$tmp" || true
  else
    cat >"$tmp" <<'HDR'
# User-local orchestrator configuration (not committed). See docs/setup.md — ".env.local".
HDR
  fi
  printf 'PROJECTS_ROOT=%q\n' "$pr" >>"$tmp"
  mv "$tmp" "$ENV_LOCAL"
  PROJECTS_ROOT="$pr"
}

# Align with session-memory.sh is_valid_session_id — reject path traversal in ACTIVE_SESSION.
is_valid_session_id() {
  local id="${1:-}"
  [ -n "$id" ] || return 1
  case "$id" in
    *..*|*/*|*\\*)
      return 1
      ;;
  esac
  if [ "${#id}" -gt 128 ]; then
    return 1
  fi
  [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  return 0
}

# Populated by collect_subdirs (global for Bash 3.2 select menu).
paths=()

collect_subdirs() {
  local base="$1"
  paths=()
  local d
  while IFS= read -r d; do
    [ -n "$d" ] && paths+=("$d")
  done < <(find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)
}

resolve_session_id() {
  local sid=""
  if [ -f "$ROOT/docs/sessions/ACTIVE_SESSION" ]; then
    sid=$(head -n 1 "$ROOT/docs/sessions/ACTIVE_SESSION" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -n "$sid" ] && is_valid_session_id "$sid" && [ -d "$ROOT/docs/sessions/$sid" ]; then
      printf '%s' "$sid"
      return 0
    fi
  fi
  "$SM" begin-run attach
}

NO_CURSOR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-cursor) NO_CURSOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "attach-project: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

ensure_projects_root
collect_subdirs "$PROJECTS_ROOT"
if [ "${#paths[@]}" -eq 0 ]; then
  echo "attach-project: no subdirectories under PROJECTS_ROOT: $PROJECTS_ROOT" >&2
  exit 1
fi

names=()
for d in "${paths[@]}"; do
  names+=("$(basename "$d")")
done
names+=("Quit")

PS3="Select project (number): "
select choice in "${names[@]}"; do
  [ -n "${choice:-}" ] || continue
  if [ "$choice" = "Quit" ]; then
    echo "Aborted." >&2
    exit 0
  fi
  idx=$((REPLY - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#paths[@]}" ]; then
    echo "Invalid selection." >&2
    continue
  fi
  TARGET_RAW="${paths[$idx]}"
  break
done

TARGET_ROOT="$(cd "$TARGET_RAW" && pwd -P)"
ORCH_ROOT="$ROOT"

session_id="$(resolve_session_id)"
session_dir="$ROOT/docs/sessions/$session_id"
mkdir -p "$session_dir"
out="$session_dir/session.code-workspace"

"$GEN" "$ORCH_ROOT" "$TARGET_ROOT" "$out"
printf '%s\n' "$TARGET_ROOT" >"$session_dir/attach-target.txt"

echo "Wrote: $out" >&2

if [ "$NO_CURSOR" -eq 1 ]; then
  exit 0
fi

if ! command -v cursor >/dev/null 2>&1; then
  echo "attach-project: 'cursor' not on PATH. Open the workspace manually:" >&2
  echo "  cursor $out" >&2
  exit 1
fi

exec cursor "$out"
