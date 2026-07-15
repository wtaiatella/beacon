#!/usr/bin/env bash
# Pre-plan handoff files under docs/sessions/<id>/pre-plan/.
# Requires an active session (pipeline: session-memory.sh begin-run or new-session; hook may use init).
# Paths are resolved via session-memory.sh session-root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_MEMORY="$SCRIPT_DIR/session-memory.sh"

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

ensure_active_session() {
  if ! "$SESSION_MEMORY" active-path >/dev/null 2>&1; then
    "$SESSION_MEMORY" init
  fi
}

session_root_abs() {
  local rel
  rel=$("$SESSION_MEMORY" session-root) || return 1
  printf '%s/%s\n' "$ROOT" "$rel"
}

read_body() {
  local path="${1:-}"
  if [ -z "$path" ] || [ "$path" = "-" ]; then
    if [ -t 0 ]; then
      echo "session-handoff: provide a file path or redirect stdin (use - for stdin explicitly)" >&2
      return 1
    fi
    cat
  else
    cat "$path"
  fi
}

valid_specialist() {
  case "$1" in
    glean|arc|jira|confluence|gitlab) return 0 ;;
    *)
      echo "session-handoff: invalid specialist '$1' (expected: glean, arc, jira, confluence, gitlab)" >&2
      return 1
      ;;
  esac
}

cmd_write_handoff() {
  local kind="${1:-}"
  shift || true
  case "$kind" in
    merged)
      ensure_active_session
      local base ts out
      base="$(session_root_abs)" || exit 1
      ts="$(iso_now)"
      out="$base/pre-plan/merged-brief.md"
      mkdir -p "$(dirname "$out")"
      {
        printf '%s\n' '---'
        printf '%s\n' 'kind: merged-brief'
        printf '%s\n' "written: ${ts}"
        printf '%s\n' '---'
        printf '\n'
        read_body "${1:-}"
      } >"$out"
      printf '%s\n' "${out#"$ROOT"/}"
      ;;
    specialist)
      local name="${1:-}"
      shift || true
      [ -n "$name" ] || {
        echo "session-handoff: specialist name required" >&2
        exit 1
      }
      valid_specialist "$name" || exit 1
      ensure_active_session
      local base ts out
      base="$(session_root_abs)" || exit 1
      ts="$(iso_now)"
      mkdir -p "$base/pre-plan/specialists"
      out="$base/pre-plan/specialists/${name}.md"
      {
        printf '%s\n' '---'
        printf '%s\n' 'kind: specialist'
        printf '%s\n' "specialist: ${name}"
        printf '%s\n' "written: ${ts}"
        printf '%s\n' '---'
        printf '\n'
        read_body "${1:-}"
      } >"$out"
      printf '%s\n' "${out#"$ROOT"/}"
      ;;
    *)
      echo "session-handoff: first argument must be 'merged' or 'specialist'" >&2
      return 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: session-handoff.sh write-handoff merged [content-file]
       session-handoff.sh write-handoff specialist <name> [content-file]

Writes pre-plan handoff artifacts under the active session:
  docs/sessions/<id>/pre-plan/merged-brief.md
  docs/sessions/<id>/pre-plan/specialists/<name>.md   (name: glean|arc|jira|confluence|gitlab)

content-file:
  - Path to a file to copy into the artifact, or omit / use - with stdin redirected.

Requires: scripts/tools/session-memory.sh session-root (active session). Creates a session via init if none.

Examples:
  session-handoff.sh write-handoff merged /tmp/brief.md
  ./scripts/tools/session-memory.sh session-root
  printf '%s\n' '## Brief' | session-handoff.sh write-handoff merged -
EOF
}

case "${1:-}" in
  write-handoff)
    shift
    cmd_write_handoff "$@"
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    usage >&2
    exit 1
    ;;
  *)
    echo "session-handoff: unknown command: ${1:-}" >&2
    usage >&2
    exit 1
    ;;
esac
