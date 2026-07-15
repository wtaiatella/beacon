#!/usr/bin/env bash
# Session memory under docs/sessions/<session-id>/current.md (gitignored).
# Active session id is stored in docs/sessions/ACTIVE_SESSION (one line, plain text; portable — no symlink).
# Session id format: UTC YYYY-MM-DDTHHMMSSZ with optional -slug suffix (kebab-case).
#
# init vs begin-run / new-session:
#   - init — Used by .cursor/hooks/session-init.sh after prune. If ACTIVE_SESSION already points at
#     an existing directory, init is a no-op (keeps the same id). That is hook-friendly: opening the
#     editor repeatedly must not mint a new folder every time.
#   - begin-run [slug] — Documented entry for run-pipeline §2 when /run is invoked WITHOUT --resume.
#     Always allocates a NEW id, writes ACTIVE_SESSION, creates docs/sessions/<id>/current.md template.
#     Same behavior as new-session [slug]; use begin-run in SKILL/docs so pipeline rotation is not
#     confused with init.
#   - new-session [slug] — Same allocation as begin-run; kept for interactive/script callers.
#
# Commands: read, write "<entry>", clear, prune, init, begin-run [slug], new-session [slug], active-path, session-root,
#           detach-workspace, phase-security-path <N>, write-trace-anchors [--resume], trace-hash-root, --help
# Stale files are pruned at session start via session-init hook (not on a timer).
#
# Layout: All pipeline log lines (DECISION:, QUESTION:, GATE:, free-form context, trace anchors) are
# appended under "## Timeline" in strict wall-clock order — no mid-file rewrites.
#
# ROAD-51: Bounded artifact namespaces under docs/sessions/<id>/artifacts/ — created by
# ensure_artifacts_dirs (idempotent mkdir -p) from begin-run / new-session / init / session writes.
#
# ROAD-54 (artifacts/scanners/): ensure_artifacts_dirs only creates the directory; filenames are
# owned by the orchestrator. Use one file per § 6 phase gate so multi-phase runs do not overwrite:
#   phase-<N>-security.md   — § 6 shift-left scan (N matches ### Phase N:, or N=1 when no phase headings)
# Session-level § 7.0 QA prep (unchanged): spec-validator.md, security-scanner.md — distinct names.
# Resolve the canonical workspace-relative path:  phase-security-path <N>
#
# Optional audit lines (after /run Finish; human audit only — not for automated execution):
#   COMMIT_SUGGESTIONS: ...
#   PUSH_CONFIRMED: yes|no
#   MR_TARGET_BRANCH: <name>|n/a
#   MR_CONFIRMED: yes|no
# Store via: session-memory.sh write "COMMIT_SUGGESTIONS: ..."
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_DIR="$ROOT/docs/sessions"
ACTIVE_SESSION_FILE="$SESSION_DIR/ACTIVE_SESSION"
LEGACY_SESSION_FILE="$SESSION_DIR/current.md"

SESSION_SUBDIR=""
SESSION_FILE=""

# ROAD-48 attach / Finish detach filenames under docs/sessions/<id>/
ATTACH_TARGET_FILE="attach-target.txt"
SESSION_CODE_WORKSPACE_FILE="session.code-workspace"

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# High-precision UTC for SESSION_START; milliseconds, Z suffix.
session_start_utc() {
  python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z")' 2>/dev/null || iso_now
}

ensure_session_dir() { mkdir -p "$SESSION_DIR"; }

# ROAD-54 / QA: session directory names must not traverse outside docs/sessions/.
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

read_active_id() {
  if [ ! -f "$ACTIVE_SESSION_FILE" ]; then
    return 1
  fi
  local id
  id=$(head -n 1 "$ACTIVE_SESSION_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "${id:-}" ]; then
    return 1
  fi
  if ! is_valid_session_id "$id"; then
    echo "session-memory: ACTIVE_SESSION id is invalid or unsafe (reject .., /, \\, or bad characters): ${id}" >&2
    return 1
  fi
  printf '%s' "$id"
}

set_paths_for_id() {
  local id="$1"
  SESSION_SUBDIR="$SESSION_DIR/$id"
  SESSION_FILE="$SESSION_SUBDIR/current.md"
}

sanitize_slug() {
  local s="$1"
  s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-//;s/-$//')
  s="${s:0:64}"
  printf '%s' "$s"
}

# ROAD-51: Least-privilege artifact routing — empty dirs OK until orchestrator writes.
# Canonical trees live only under artifacts/* (no session-root symlink aliases).
# Subdir artifacts/scanners/ holds phase-<N>-security.md (§ 6, one per N) and § 7.0 session files — see header.
ensure_artifacts_dirs() {
  local root="${1:-}"
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    return 1
  fi
  mkdir -p \
    "$root/artifacts/mcp-briefs" \
    "$root/artifacts/explorer" \
    "$root/artifacts/scanners" \
    "$root/artifacts/diffs/dev" \
    "$root/artifacts/diffs/sre" \
    "$root/artifacts/diffs/data" \
    "$root/artifacts/diffs/plan"
}

new_session_id() {
  local slug="${1:-}"
  local base
  base=$(date -u +"%Y-%m-%dT%H%M%SZ")
  if [ -n "$slug" ]; then
    slug=$(sanitize_slug "$slug")
    if [ -n "$slug" ]; then
      printf '%s-%s' "$base" "$slug"
    else
      printf '%s' "$base"
    fi
  else
    printf '%s' "$base"
  fi
}

write_active_id() {
  local id="$1"
  if ! is_valid_session_id "$id"; then
    echo "session-memory: write_active_id: invalid session id" >&2
    return 1
  fi
  mkdir -p "$SESSION_DIR"
  printf '%s\n' "$id" >"$ACTIVE_SESSION_FILE"
}

ensure_template_file() {
  local f="$1"
  if [ ! -f "$f" ]; then
    local ts
    ts="$(iso_now)"
    mkdir -p "$(dirname "$f")"
    cat >"$f" <<EOF
# Session Memory
Last updated: ${ts}

## Timeline

EOF
  fi
}

migrate_legacy_current() {
  if [ ! -f "$LEGACY_SESSION_FILE" ]; then
    return 1
  fi
  if [ -d "$LEGACY_SESSION_FILE" ]; then
    return 1
  fi
  local id
  id="$(new_session_id)"
  local dest_dir="$SESSION_DIR/$id"
  mkdir -p "$dest_dir"
  mv "$LEGACY_SESSION_FILE" "$dest_dir/current.md"
  ensure_artifacts_dirs "$dest_dir" || true
  write_active_id "$id"
  return 0
}

# Hook: after prune — ensure ACTIVE_SESSION + dir exist when missing/invalid; reuse valid id if present.
# Does NOT rotate to a fresh id (that would allocate a new folder on every editor start). For each
# /run without --resume, the orchestrator must call begin-run (or new-session), not init.
cmd_init() {
  ensure_session_dir
  if [ -f "$LEGACY_SESSION_FILE" ] && [ ! -L "$LEGACY_SESSION_FILE" ]; then
    migrate_legacy_current
    return 0
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -n "$id" ] && [ -d "$SESSION_DIR/$id" ]; then
    ensure_artifacts_dirs "$SESSION_DIR/$id" || true
    touch "$ACTIVE_SESSION_FILE" 2>/dev/null || true
    return 0
  fi
  id="$(new_session_id)"
  set_paths_for_id "$id"
  mkdir -p "$SESSION_SUBDIR"
  ensure_artifacts_dirs "$SESSION_SUBDIR" || true
  write_active_id "$id"
  ensure_template_file "$SESSION_FILE"
}

# Resolve SESSION_FILE for read/write; create session + template if needed (write path).
ensure_session_for_write() {
  if [ -f "$LEGACY_SESSION_FILE" ] && [ ! -L "$LEGACY_SESSION_FILE" ]; then
    migrate_legacy_current
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "${SESSION_DIR:-}/$id" ]; then
    id="$(new_session_id)"
    set_paths_for_id "$id"
    mkdir -p "$SESSION_SUBDIR"
    write_active_id "$id"
  else
    set_paths_for_id "$id"
  fi
  SESSION_FILE="$SESSION_SUBDIR/current.md"
  ensure_artifacts_dirs "$SESSION_SUBDIR" || true
}

update_last_updated() {
  local f="$1" ts="$2" tmp
  tmp="$(mktemp)"
  awk -v ts="$ts" '/^Last updated: / && !d { print "Last updated: " ts; d=1; next } { print }' "$f" >"$tmp"
  mv "$tmp" "$f"
}

ensure_file() {
  ensure_session_for_write
  if [ ! -f "$SESSION_FILE" ]; then
    local ts
    ts="$(iso_now)"
    mkdir -p "$(dirname "$SESSION_FILE")"
    cat >"$SESSION_FILE" <<EOF
# Session Memory
Last updated: ${ts}

## Timeline

EOF
  fi
}

# Append ## Timeline at EOF if missing (legacy files or pre-Timeline templates).
ensure_timeline_section() {
  ensure_file
  if ! grep -q '^## Timeline$' "$SESSION_FILE"; then
    printf '\n## Timeline\n\n' >>"$SESSION_FILE"
  fi
}

# Append one timestamped bullet line to the Timeline (append-only at EOF).
append_timeline_bullet() {
  local bullet="$1"
  ensure_timeline_section
  printf '%s\n' "$bullet" >>"$SESSION_FILE"
  update_last_updated "$SESSION_FILE" "$(iso_now)"
}

cmd_read() {
  if [ -f "$LEGACY_SESSION_FILE" ] && [ ! -L "$LEGACY_SESSION_FILE" ]; then
    migrate_legacy_current
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    echo "No active session."
    return 0
  fi
  set_paths_for_id "$id"
  if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
    echo "No active session."
    return 0
  fi
  if ! grep -q '[^[:space:]]' "$SESSION_FILE"; then
    echo "No active session."
    return 0
  fi
  cat "$SESSION_FILE"
}

cmd_write() {
  local entry="$1" ts bullet rest
  ts="$(iso_now)"
  if [[ "$entry" =~ ^DECISION:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
    append_timeline_bullet "$bullet"
  elif [[ "$entry" =~ ^QUESTION:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
    append_timeline_bullet "$bullet"
  elif [[ "$entry" =~ ^GATE:[[:space:]]*(.*)$ ]]; then
    rest="${BASH_REMATCH[1]}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    bullet="- ${ts} | ${rest}"
    append_timeline_bullet "$bullet"
  else
    bullet="- ${ts} | ${entry}"
    append_timeline_bullet "$bullet"
  fi
}

cmd_clear() {
  ensure_session_dir
  if [ -f "$LEGACY_SESSION_FILE" ] && [ ! -d "$LEGACY_SESSION_FILE" ]; then
    rm -f "$LEGACY_SESSION_FILE"
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -n "$id" ] && [ -d "$SESSION_DIR/$id" ]; then
    rm -f "$SESSION_DIR/$id/current.md"
  fi
}

cmd_prune() {
  ensure_session_dir
  # Remove session files older than 24h; never delete the ACTIVE_SESSION pointer at repo root of docs/sessions/.
  find "$SESSION_DIR" -type f -mmin +1440 ! -name ACTIVE_SESSION -delete 2>/dev/null || true
  # Optional: remove empty timestamped session directories (pointer file exempt; never remove SESSION_DIR itself).
  find "$SESSION_DIR" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
}

cmd_new_session() {
  local slug="${1:-}"
  ensure_session_dir
  local id
  id="$(new_session_id "$slug")"
  set_paths_for_id "$id"
  mkdir -p "$SESSION_SUBDIR"
  ensure_artifacts_dirs "$SESSION_SUBDIR" || true
  write_active_id "$id"
  ensure_template_file "$SESSION_FILE"
  printf '%s\n' "$id"
}

# Pipeline §2 Init: fresh session for each /run without --resume — delegates to new-session.
cmd_begin_run() {
  cmd_new_session "${1:-}"
}

cmd_active_path() {
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    return 1
  fi
  printf 'docs/sessions/%s/current.md\n' "$id"
}

# Workspace-relative directory for the active session (parent of current.md and pre-plan/).
cmd_session_root() {
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    return 1
  fi
  printf 'docs/sessions/%s\n' "$id"
}

# ROAD-48 Finish: delete only session.code-workspace under the active session dir. Preserves
# current.md, attach-target.txt, artifacts/, pre-plan/, and all other session history.
cmd_detach_workspace() {
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    echo "session-memory: detach-workspace: no active session" >&2
    return 1
  fi
  set_paths_for_id "$id"
  local ws="$SESSION_SUBDIR/$SESSION_CODE_WORKSPACE_FILE"
  if [ -f "$ws" ]; then
    rm -f "$ws"
    printf '%s\n' "session-memory: removed docs/sessions/$id/$SESSION_CODE_WORKSPACE_FILE"
  else
    printf '%s\n' "session-memory: detach-workspace: no $SESSION_CODE_WORKSPACE_FILE (nothing to remove)"
  fi
}

# ROAD-48: Multi-root attach — session dir may contain attach-target.txt (one line: absolute target repo root).
# write-trace-anchors and trace-hash-root use it for cursor-project-hash when present and valid.

# Resolve absolute path passed to cursor-project-hash.sh for PROJECT_HASH (requires set_paths_for_id).
resolve_trace_hash_root() {
  local attach_file="${SESSION_SUBDIR}/${ATTACH_TARGET_FILE}"
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
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    echo "session-memory: trace-hash-root: no active session (run begin-run first)" >&2
    return 1
  fi
  set_paths_for_id "$id"
  resolve_trace_hash_root
}

# ROAD-54: Print workspace-relative path for § 6 phase security report (phase-<N>-security.md).
# Ensures artifact dirs exist (ensure_artifacts_dirs). Does not write the file — orchestrator persists
# Task(security-scanner) output there; no separate wrapper script required for phase-impl-delta.
cmd_phase_security_path() {
  local n="${1:-}"
  if ! [[ "${n:-}" =~ ^[1-9][0-9]*$ ]]; then
    echo "session-memory: phase-security-path requires a positive integer phase number (e.g. 1, 2)" >&2
    return 1
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    echo "session-memory: phase-security-path: no active session (run begin-run first)" >&2
    return 1
  fi
  set_paths_for_id "$id"
  ensure_artifacts_dirs "$SESSION_SUBDIR" || true
  printf 'docs/sessions/%s/artifacts/scanners/phase-%s-security.md\n' "$id" "$n"
}

# Trace anchors: append SESSION_START + PROJECT_HASH under ## Timeline (idempotent).
# Skips if both lines already exist (same trace window — e.g. /run --resume).
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

  if [ -f "$LEGACY_SESSION_FILE" ] && [ ! -L "$LEGACY_SESSION_FILE" ]; then
    migrate_legacy_current
  fi
  local id
  id=$(read_active_id) || id=""
  if [ -z "$id" ] || [ ! -d "$SESSION_DIR/$id" ]; then
    echo "session-memory: write-trace-anchors: no active session (run begin-run first)" >&2
    return 1
  fi
  set_paths_for_id "$id"
  ensure_file

  if grep -q '^SESSION_START:' "$SESSION_FILE" && grep -q '^PROJECT_HASH:' "$SESSION_FILE"; then
    return 0
  fi

  if [ "$resume_mode" -eq 1 ]; then
    echo "session-memory: write-trace-anchors: missing anchors but --resume set; not writing (expected anchors from prior begin-run)" >&2
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
  } >>"$SESSION_FILE"
  update_last_updated "$SESSION_FILE" "$(iso_now)"
}

usage() {
  cat <<'EOF'
Usage: session-memory.sh <command>

  read              Print current session memory (or "No active session.")
  write "<entry>"   Append a timestamped entry to ## Timeline (DECISION:/QUESTION:/GATE: or context)
  clear             Remove the active session memory file (same session id; see docs/run-pipeline-reference.md)
  prune             Remove session files untouched for >24h; drop empty session dirs (called by session-init hook)
  init              Ensure ACTIVE_SESSION + session dir (hook: after prune; reuses valid id — does not rotate)
  begin-run [slug]  Fresh session for /run without --resume; set ACTIVE_SESSION + template (same as new-session)
  new-session [slug] Start a new timestamped session (optional kebab slug); set ACTIVE_SESSION
  active-path       Print workspace-relative path to current.md for the active session (exit 1 if none)
  session-root      Print workspace-relative path to the active session directory (exit 1 if none)
  detach-workspace  Remove only docs/sessions/<id>/session.code-workspace (ROAD-48 Finish); keeps session history
  phase-security-path <N>
                    Print workspace-relative path for § 6 scanner output: artifacts/scanners/phase-<N>-security.md
                    (ROAD-54; N matches ### Phase N:, or use 1 for single implicit phase). Ensures artifact dirs.
  write-trace-anchors [--resume]
                    Trace anchors: append SESSION_START + PROJECT_HASH under ## Timeline (idempotent).
                    Skips if anchors exist. With --resume, skips writing when anchors are missing
                    (resume continues the same trace window; orchestrator should not mint new anchors).
                    PROJECT_HASH uses cursor-project-hash on the target root when docs/sessions/<id>/attach-target.txt
                    exists (ROAD-48); otherwise the orchestrator repo root.
  trace-hash-root   Print the absolute directory passed to cursor-project-hash for the active session (same logic as write-trace-anchors).

Prefixes: DECISION:, QUESTION:, GATE: — otherwise stored as Timeline bullets.

Optional (append as plain write strings for post-pipeline audit):
  COMMIT_SUGGESTIONS:, PUSH_CONFIRMED:, MR_TARGET_BRANCH:, MR_CONFIRMED:

Chronology: All writes append at EOF under ## Timeline. For a successful Finish, write PIPELINE: COMPLETE
last (after audit-session-trace.py and optional Finish audit lines) — see run-pipeline SKILL § 9.

Layout: docs/sessions/ACTIVE_SESSION (one line: session id), docs/sessions/<session-id>/current.md
        Artifacts (ROAD-51): docs/sessions/<session-id>/artifacts/{mcp-briefs,explorer,scanners,diffs/{dev,sre,data,plan}}/
        Scanners (ROAD-54): § 6 phase-<N>-security.md (one per phase); § 7.0 spec-validator.md + security-scanner.md
        Pre-plan handoffs: docs/sessions/<session-id>/pre-plan/ (see scripts/tools/session-handoff.sh)
EOF
}

case "${1:-}" in
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
  prune) cmd_prune ;;
  init) cmd_init ;;
  begin-run)
    shift
    cmd_begin_run "${1:-}"
    ;;
  new-session)
    shift
    cmd_new_session "${1:-}"
    ;;
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
  "")
    usage >&2
    exit 1
    ;;
  *)
    echo "session-memory: unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
