#!/usr/bin/env bash
# Pre-plan handoff files under <ticket>/_run/pre-plan/.
# Requires --ticket (the same folder pipeline-init ensured).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_MEMORY="$SCRIPT_DIR/session-memory.sh"

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

TICKET=""

session_root_abs() {
  local rel
  rel=$("$SESSION_MEMORY" --ticket "$TICKET" session-root) || return 1
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
  # Built-ins (system-design, repro, jira, …) and project skill names are
  # kebab-case. Reject path separators so a name cannot escape specialists/.
  if [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]]; then
    return 0
  fi
  echo "session-handoff: invalid specialist '$1' (expected kebab-case, e.g. repro, jira, reproduce-issue)" >&2
  return 1
}

cmd_write_handoff() {
  local kind="${1:-}"
  shift || true
  case "$kind" in
    merged)
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
Usage: session-handoff.sh --ticket <docs/specs/...> write-handoff merged [content-file]
       session-handoff.sh --ticket <docs/specs/...> write-handoff specialist <name> [content-file]

Writes pre-plan handoff artifacts under the ticket run dir:
  <ticket>/_run/pre-plan/merged-brief.md
  <ticket>/_run/pre-plan/specialists/<name>.md   (kebab-case name)

content-file:
  - Path to a file to copy into the artifact, or omit / use - with stdin redirected.

Requires: session-memory.sh --ticket <folder> ensure already created _run/.

Examples:
  session-handoff.sh --ticket docs/specs/2026-10-14-BG-1-slug write-handoff merged /tmp/brief.md
  printf '%s\n' '## Brief' | session-handoff.sh --ticket docs/specs/2026-10-14-BG-1-slug write-handoff merged -
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ -z "${1:-}" ]; then
  usage
  [ -n "${1:-}" ] || exit 1
  exit 0
fi

if [ "${1:-}" != "--ticket" ] || [ $# -lt 3 ]; then
  echo "session-handoff: --ticket <docs/specs/...> is required" >&2
  usage >&2
  exit 1
fi
TICKET="$2"
shift 2

case "${1:-}" in
  write-handoff)
    shift
    cmd_write_handoff "$@"
    ;;
  *)
    echo "session-handoff: unknown command: ${1:-}" >&2
    usage >&2
    exit 1
    ;;
esac
