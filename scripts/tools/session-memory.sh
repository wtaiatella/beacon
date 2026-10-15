#!/usr/bin/env bash
# Run timeline for one ticket folder: <ticket>/_run/timeline.md.
# The ticket path is the identity. There is no docs/sessions/ACTIVE_SESSION.
#
# Usage: session-memory.sh --ticket <docs/specs/...> <command>
#
# Commands: read, write "<entry>", clear, ensure, active-path, session-root,
#           detach-workspace, phase-security-path <N>, write-trace-anchors [--resume],
#           trace-hash-root, --help
#
# init, prune, begin-run, and new-session are gone. /fix and /do do not call this.
#
# Layout:
#   <ticket>/pre-plan/{merged-brief.md,review.md,gate.md,specialists/}
#   <ticket>/_run/: timeline.md, audit.log, attach-target.txt, session.code-workspace
#   <ticket>/_run/{explorer,scanners,diffs/{dev,sre,data,plan}}/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TICKET_REL=""
RUN_REL=""
RUN_ABS=""
TIMELINE=""

ATTACH_TARGET_FILE="attach-target.txt"
SESSION_CODE_WORKSPACE_FILE="session.code-workspace"

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

session_start_utc() {
  python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z")' 2>/dev/null || iso_now
}

# Ticket folder must be workspace-relative, under docs/specs/, with no traversal.
resolve_ticket() {
  local raw="$1"
  raw="${raw#./}"
  raw="${raw%/}"
  case "$raw" in
    ""|.*|*..*|/*|*\\*)
      echo "session-memory: --ticket must be a workspace-relative docs/specs/ folder: ${raw:-<empty>}" >&2
      return 1
      ;;
  esac
  case "$raw" in
    docs/specs/*) ;;
    *)
      echo "session-memory: --ticket must start with docs/specs/: $raw" >&2
      return 1
      ;;
  esac
  if [ ! -d "$ROOT/$raw" ]; then
    echo "session-memory: ticket folder does not exist: $raw" >&2
    return 1
  fi
  TICKET_REL="$raw"
  RUN_REL="$TICKET_REL/_run"
  RUN_ABS="$ROOT/$RUN_REL"
  TIMELINE="$RUN_ABS/timeline.md"
}

ensure_run_dirs() {
  mkdir -p \
    "$ROOT/$TICKET_REL/pre-plan/specialists" \
    "$RUN_ABS/explorer" \
    "$RUN_ABS/scanners" \
    "$RUN_ABS/diffs/dev" \
    "$RUN_ABS/diffs/sre" \
    "$RUN_ABS/diffs/data" \
    "$RUN_ABS/diffs/plan"
}

ensure_template_file() {
  if [ ! -f "$TIMELINE" ]; then
    local ts
    ts="$(iso_now)"
    mkdir -p "$(dirname "$TIMELINE")"
    cat >"$TIMELINE" <<EOF
# Run timeline
Last updated: ${ts}

## Timeline

EOF
  fi
}

cmd_ensure() {
  ensure_run_dirs
  ensure_template_file
  printf '%s\n' "$RUN_REL"
}

require_run() {
  if [ ! -f "$TIMELINE" ]; then
    echo "session-memory: no timeline at $RUN_REL/timeline.md (run ensure first)" >&2
    return 1
  fi
}

update_last_updated() {
  local f="$1" ts="$2" tmp
  tmp="$(mktemp)"
  awk -v ts="$ts" '/^Last updated: / && !d { print "Last updated: " ts; d=1; next } { print }' "$f" >"$tmp"
  mv "$tmp" "$f"
}

ensure_timeline_section() {
  ensure_template_file
  if ! grep -q '^## Timeline$' "$TIMELINE"; then
    printf '\n## Timeline\n\n' >>"$TIMELINE"
  fi
}

append_timeline_bullet() {
  local bullet="$1"
  ensure_timeline_section
  printf '%s\n' "$bullet" >>"$TIMELINE"
  update_last_updated "$TIMELINE" "$(iso_now)"
}

cmd_read() {
  if [ ! -f "$TIMELINE" ] || [ ! -s "$TIMELINE" ]; then
    echo "No run timeline."
    return 0
  fi
  if ! grep -q '[^[:space:]]' "$TIMELINE"; then
    echo "No run timeline."
    return 0
  fi
  cat "$TIMELINE"
}

cmd_write() {
  local entry="$1" ts bullet rest
  ts="$(iso_now)"
  ensure_run_dirs
  if [[ "$entry" =~ ^DECISION:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
  elif [[ "$entry" =~ ^QUESTION:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
  elif [[ "$entry" =~ ^GATE:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
  else
    bullet="- ${ts} | ${entry}"
  fi
  append_timeline_bullet "$bullet"
}

cmd_clear() {
  rm -f "$TIMELINE"
}

cmd_active_path() {
  require_run
  printf '%s/timeline.md\n' "$RUN_REL"
}

cmd_session_root() {
  if [ ! -d "$RUN_ABS" ]; then
    echo "session-memory: no _run directory (run ensure first)" >&2
    return 1
  fi
  printf '%s\n' "$RUN_REL"
}

cmd_detach_workspace() {
  local ws="$RUN_ABS/$SESSION_CODE_WORKSPACE_FILE"
  if [ ! -d "$RUN_ABS" ]; then
    echo "session-memory: detach-workspace: no _run directory" >&2
    return 1
  fi
  if [ -f "$ws" ]; then
    rm -f "$ws"
    printf '%s\n' "session-memory: removed $RUN_REL/$SESSION_CODE_WORKSPACE_FILE"
  else
    printf '%s\n' "session-memory: detach-workspace: no $SESSION_CODE_WORKSPACE_FILE (nothing to remove)"
  fi
}

resolve_trace_hash_root() {
  local attach_file="${RUN_ABS}/${ATTACH_TARGET_FILE}"
  if [ ! -f "$attach_file" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  local line
  line=$(head -n 1 "$attach_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$line" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  if [ ! -d "$line" ]; then
    echo "session-memory: attach-target.txt path is not a directory: $line" >&2
    return 1
  fi
  (cd "$line" && pwd -P)
}

cmd_trace_hash_root() {
  if [ ! -d "$RUN_ABS" ]; then
    echo "session-memory: trace-hash-root: no _run directory (run ensure first)" >&2
    return 1
  fi
  resolve_trace_hash_root
}

cmd_phase_security_path() {
  local n="${1:-}"
  if ! [[ "${n:-}" =~ ^[1-9][0-9]*$ ]]; then
    echo "session-memory: phase-security-path requires a positive integer phase number (e.g. 1, 2)" >&2
    return 1
  fi
  ensure_run_dirs
  printf '%s/scanners/phase-%s-security.md\n' "$RUN_REL" "$n"
}

cmd_write_trace_anchors() {
  local resume_mode=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --resume) resume_mode=1; shift ;;
      *)
        echo "session-memory: write-trace-anchors: unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  ensure_run_dirs
  ensure_template_file

  if grep -q '^SESSION_START:' "$TIMELINE" && grep -q '^PROJECT_HASH:' "$TIMELINE"; then
    return 0
  fi

  if [ "$resume_mode" -eq 1 ]; then
    echo "session-memory: write-trace-anchors: missing anchors but --resume set; not writing" >&2
    return 0
  fi

  local ph ss hash_cmd trace_root
  hash_cmd="$SCRIPT_DIR/cursor-project-hash.sh"
  if [ ! -f "$hash_cmd" ]; then
    echo "session-memory: write-trace-anchors: missing $hash_cmd" >&2
    return 1
  fi
  trace_root="$(resolve_trace_hash_root)" || return 1
  ph="$(bash "$hash_cmd" "$trace_root")"
  ss="$(session_start_utc)"
  ensure_timeline_section
  {
    printf '%s\n' "SESSION_START: $ss"
    printf '%s\n' "PROJECT_HASH: $ph"
  } >>"$TIMELINE"
  update_last_updated "$TIMELINE" "$(iso_now)"
}

usage() {
  cat <<'EOF'
Usage: session-memory.sh --ticket <docs/specs/...> <command>

  ensure            Create <ticket>/_run/ and timeline.md if missing. Prints the _run path.
  read              Print the run timeline (or "No run timeline.")
  write "<entry>"   Append a timestamped entry to ## Timeline
  clear             Remove timeline.md only
  active-path       Print workspace-relative path to timeline.md
  session-root      Print workspace-relative path to <ticket>/_run
  detach-workspace  Remove only <ticket>/_run/session.code-workspace
  phase-security-path <N>
                    Print <ticket>/_run/scanners/phase-<N>-security.md
  write-trace-anchors [--resume]
                    Append SESSION_START + PROJECT_HASH under ## Timeline (idempotent).
                    PROJECT_HASH uses <ticket>/_run/attach-target.txt when that file names a directory.
  trace-hash-root   Print the absolute directory used for PROJECT_HASH.

/fix and /do do not use this file. There is no global session id and no 24h prune.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ -z "${1:-}" ]; then
  usage
  [ -n "${1:-}" ] || exit 1
  exit 0
fi

if [ "${1:-}" != "--ticket" ]; then
  echo "session-memory: --ticket <docs/specs/...> is required (got: ${1:-})" >&2
  usage >&2
  exit 1
fi
shift
if [ $# -lt 2 ]; then
  echo "session-memory: --ticket needs a folder and a command" >&2
  usage >&2
  exit 1
fi
resolve_ticket "$1" || exit 1
shift

case "${1:-}" in
  ensure) cmd_ensure ;;
  read) cmd_read ;;
  write)
    shift
    if [ $# -eq 0 ]; then
      echo "session-memory: write requires an entry string" >&2
      exit 1
    fi
    cmd_write "$*"
    ;;
  clear) cmd_clear ;;
  active-path) cmd_active_path ;;
  session-root) cmd_session_root ;;
  detach-workspace) cmd_detach_workspace ;;
  phase-security-path)
    shift
    if [ $# -ne 1 ]; then
      echo "session-memory: phase-security-path requires exactly one argument (phase number)" >&2
      exit 1
    fi
    cmd_phase_security_path "$1"
    ;;
  write-trace-anchors)
    shift
    cmd_write_trace_anchors "$@"
    ;;
  trace-hash-root) cmd_trace_hash_root ;;
  --help|-h) usage ;;
  *)
    echo "session-memory: unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
