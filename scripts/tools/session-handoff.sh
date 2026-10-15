#!/usr/bin/env bash
# Pre-plan documents under <ticket>/pre-plan/ (sibling of _run, not inside it).
# Requires --ticket (the ticket folder must already exist).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

TICKET=""

ticket_abs() {
  if [ ! -d "$ROOT/$TICKET" ]; then
    echo "session-handoff: ticket folder does not exist: $TICKET" >&2
    return 1
  fi
  printf '%s/%s\n' "$ROOT" "$TICKET"
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
  local base
  base="$(ticket_abs)" || exit 1
  case "$kind" in
    merged)
      local ts out
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
      local ts out
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
    review)
      local ts out
      ts="$(iso_now)"
      out="$base/pre-plan/review.md"
      mkdir -p "$(dirname "$out")"
      {
        printf '%s\n' '---'
        printf '%s\n' 'kind: review'
        printf '%s\n' "written: ${ts}"
        printf '%s\n' '---'
        printf '\n'
        read_body "${1:-}"
      } >"$out"
      printf '%s\n' "${out#"$ROOT"/}"
      ;;
    gate)
      local ts out
      ts="$(iso_now)"
      out="$base/pre-plan/gate.md"
      mkdir -p "$(dirname "$out")"
      {
        printf '%s\n' '---'
        printf '%s\n' 'kind: gate'
        printf '%s\n' "written: ${ts}"
        printf '%s\n' '---'
        printf '\n'
        read_body "${1:-}"
      } >"$out"
      printf '%s\n' "${out#"$ROOT"/}"
      ;;
    *)
      echo "session-handoff: first argument must be 'merged', 'specialist', 'review', or 'gate'" >&2
      return 1
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: session-handoff.sh --ticket <docs/specs/...> write-handoff merged [content-file]
       session-handoff.sh --ticket <docs/specs/...> write-handoff specialist <name> [content-file]
       session-handoff.sh --ticket <docs/specs/...> write-handoff review [content-file]
       session-handoff.sh --ticket <docs/specs/...> write-handoff gate [content-file]

Writes pre-plan documents beside the ticket docs (not under _run/):
  <ticket>/pre-plan/merged-brief.md
  <ticket>/pre-plan/specialists/<name>.md   (kebab-case name)
  <ticket>/pre-plan/review.md
  <ticket>/pre-plan/gate.md

content-file:
  - Path to a file to copy into the artifact, or omit / use - with stdin redirected.

The ticket folder must already exist. _run/ is not required.

Examples:
  session-handoff.sh --ticket docs/specs/2026-10-14-KEY-slug write-handoff merged /tmp/brief.md
  printf '%s\n' '## Brief' | session-handoff.sh --ticket docs/specs/2026-10-14-KEY-slug write-handoff merged -
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
