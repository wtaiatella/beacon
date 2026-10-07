#!/usr/bin/env bash
# run-pipeline §2 Init — begin-run (unless --resume), trace anchors, apply-models --snapshot,
# session-memory read, optional knowledge-source note (ARC + local KB). One structured report.
# v1: workspace root only; stable stdout section headers (=== ... ===).
# Bash 3.2+ compatible.
set -euo pipefail
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SM="$ROOT/scripts/tools/session-memory.sh"
AM="$ROOT/scripts/tools/apply-models.sh"

usage() {
  cat <<'EOF'
Usage: pipeline-init.sh [--resume] [--slug <kebab-slug>] [--targets <dir> ...]

  --resume     Do not run begin-run; keep ACTIVE_SESSION (same as /run --resume).
  --slug       Optional kebab-case suffix for begin-run session id (only without --resume).
  --targets    Optional workspace-relative dirs for knowledge/<dir>/_index.md checks (§2).

Hard failures (non-zero): begin-run, write-trace-anchors, apply-models --snapshot, or
session-memory write for the optional KNOWLEDGE_SOURCES line.

Stdout: one report with fixed === section headers.

Environment:
  APPLY_MODELS_SNAPSHOT  Snapshot path override (default docs/sessions/.model-snapshot via apply-models).
EOF
}

RESUME=0
SLUG=""
TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) RESUME=1; shift ;;
    --slug)
      [ $# -ge 2 ] || { echo "pipeline-init: --slug requires a value" >&2; exit 1; }
      SLUG="$2"
      shift 2
      ;;
    --targets)
      shift
      while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
        TARGETS+=("$1")
        shift
      done
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "pipeline-init: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$RESUME" -eq 1 ] && [ -n "$SLUG" ]; then
  echo "pipeline-init: --slug is not used with --resume" >&2
  exit 1
fi

section() {
  # Closed stdout (e.g. cmd | head) must not fail the script under set -e.
  printf '%s\n' "$1" || true
}

section "=== pipeline-init ==="
section "=== flags ==="
if [ "$RESUME" -eq 1 ]; then
  section "resume: yes"
else
  section "resume: no"
fi

cd "$ROOT"

section "=== session-rotation ==="
if [ "$RESUME" -eq 0 ]; then
  NEW_ID="$("$SM" begin-run "${SLUG}")" || exit 1
  section "begin-run: ok"
  section "session-id: $NEW_ID"
else
  if ! "$SM" active-path >/dev/null 2>&1; then
    echo "pipeline-init: --resume but no active session (run begin-run first or drop --resume)" >&2
    exit 1
  fi
  section "begin-run: skipped (--resume)"
  if [ -f "$ROOT/docs/sessions/ACTIVE_SESSION" ]; then
    section "session-id: $(head -1 "$ROOT/docs/sessions/ACTIVE_SESSION" | tr -d '\r')"
  fi
fi

section "=== trace-anchors ==="
if [ "$RESUME" -eq 1 ]; then
  "$SM" write-trace-anchors --resume || exit 1
else
  "$SM" write-trace-anchors || exit 1
fi
section "write-trace-anchors: ok"
THR=$("$SM" trace-hash-root) || exit 1
section "trace-hash-root: $THR"

section "=== model-mode ==="
MSRC=$("$AM" --show-source 2>&1) || exit 1
printf '%s\n' "$MSRC" || true

section "=== apply-models-snapshot ==="
SNAPSHOT_OUT="${APPLY_MODELS_SNAPSHOT:-$ROOT/docs/sessions/.model-snapshot}"
SNAPSHOT_MSG=$("$AM" --snapshot 2>&1) || exit 1
printf '%s\n' "$SNAPSHOT_MSG" || true
section "snapshot-path: $SNAPSHOT_OUT"

section "=== session-memory-read ==="
READ_OUT=$("$SM" read 2>&1) || exit 1
LINE_COUNT=$(printf '%s\n' "$READ_OUT" | wc -l | tr -d ' ')
section "session-memory-lines: $LINE_COUNT"
printf '%s\n' "$READ_OUT" | tail -n 80 || true

section "=== knowledge-sources ==="
# ARC (AvaTax Release Central) was removed as a framework-level knowledge
# source — generic pre-plan grounding now comes from the domain specialists
# (system-design-specialist, etc.), and /kb's local knowledge/<dir>/ tree is
# the only fallback this check still considers.
KB_HIT=0
# Bash 3.2 + set -u: "${TARGETS[@]}" is "unbound" when the array is empty — guard the loop.
if [ "${#TARGETS[@]}" -gt 0 ]; then
  for t in "${TARGETS[@]}"; do
    t="${t#/}"
    if [ -f "$ROOT/knowledge/$t/_index.md" ]; then
      KB_HIT=1
      section "local-knowledge-index: knowledge/${t}/_index.md (present)"
    fi
  done
fi
if [ "${#TARGETS[@]}" -eq 0 ]; then
  section "local-knowledge-index: (no --targets; skipped)"
elif [ "$KB_HIT" -eq 0 ]; then
  section "local-knowledge-index: none of the listed targets have knowledge/<dir>/_index.md"
fi

if [ "${#TARGETS[@]}" -gt 0 ] && [ "$KB_HIT" -eq 0 ]; then
  WARN_MSG="KNOWLEDGE_SOURCES: no knowledge/<dir>/_index.md for checked targets — run /kb to build one, or rely on pre-plan domain specialists for per-ticket grounding instead."
  "$SM" write "$WARN_MSG" || exit 1
  section "session-memory-write: KNOWLEDGE_SOURCES (warning line appended)"
elif [ "${#TARGETS[@]}" -eq 0 ]; then
  section "knowledge-warning: not emitted (no --targets to evaluate local KB)"
else
  section "knowledge-warning: not emitted (local KB satisfied)"
fi

section "=== pipeline-init-status ==="
section "ok"

exit 0
