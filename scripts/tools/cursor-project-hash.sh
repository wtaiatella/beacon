#!/usr/bin/env bash
# Print the directory name Cursor uses under ~/.cursor/projects/<name>/ for a workspace root.
# Deterministic encoding aligned with observed Cursor IDE behavior on macOS/Linux.
#
# Algorithm (documented — Cursor may change; see docs/run-pipeline-reference.md):
#   1. Resolve REPO_ROOT to an absolute path with symlinks canonicalized (pwd -P).
#   2. Strip a single leading '/'.
#   3. Replace '.' with '-' (path segments often contain dots, e.g. ~/.Trash — matches
#      observed ~/.cursor/projects/Users-vivian-lied-... layout on macOS).
#   4. Replace every remaining '/' with '-'.
# Example: /Users/me/proj/foo -> Users-me-proj-foo
#
# Usage:
#   REPO_ROOT=/path ./cursor-project-hash.sh
#   ./cursor-project-hash.sh [REPO_ROOT]
#   ./cursor-project-hash.sh --verify [REPO_ROOT]   # stderr: check ~/.cursor/projects/<hash>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: cursor-project-hash.sh [--verify] [REPO_ROOT]

Print one line to stdout: the project directory name under ~/.cursor/projects/

  REPO_ROOT   Repository/workspace root (default: repo root inferred from this script,
              or override with environment variable REPO_ROOT)

  --verify    After printing the hash, write a self-check to stderr: whether
              $HOME/.cursor/projects/<hash> exists; if agent-transcripts/ is present,
              note that transcripts are available. Exit status is always 0 if the
              hash was computed (missing ~/.cursor data is not an error).

Environment:
  REPO_ROOT   Same as optional [REPO_ROOT] argument; an explicit argument wins.

Encoding: absolute path (pwd -P), strip leading '/', replace '.' with '-', then '/' with '-'.

Multi-root / .code-workspace:
  Cursor picks one filesystem path as the workspace identity under ~/.cursor/projects/<hash>/.
  This script hashes whatever directory you pass as REPO_ROOT (default: this repository's root,
  inferred from the script location). session-memory.sh write-trace-anchors runs:
    cursor-project-hash.sh <trace-root>
  where trace-root is the orchestrator repo root unless docs/sessions/<id>/attach-target.txt
  names a directory (ROAD-48 multi-root attach). If the IDE was opened on a
  different path (e.g. a .code-workspace file, another clone, or a multi-root parent folder),
  Cursor's transcript directory name may differ from this hash — use audit-session-trace.py
  zero-match diagnostics or compare ~/.cursor/projects/ entries to debug.
EOF
}

canonical_root() {
  local d="$1"
  if [ ! -d "$d" ]; then
    echo "cursor-project-hash: not a directory: $d" >&2
    return 1
  fi
  (cd "$d" && pwd -P)
}

encode_cursor_project_name() {
  local abs="$1"
  local stripped="${abs#/}"
  if [ -z "$stripped" ]; then
    echo "cursor-project-hash: cannot encode filesystem root as a project name" >&2
    return 1
  fi
  # Dots then slashes — aligns with Cursor's project folder names under ~/.cursor/projects/
  printf '%s\n' "$stripped" | tr '.' '-' | tr '/' '-'
}

do_verify() {
  local hash="$1"
  local proj="${HOME}/.cursor/projects/${hash}"
  if [ -d "$proj" ]; then
    echo "cursor-project-hash: verify: OK directory exists: $proj" >&2
    if [ -d "$proj/agent-transcripts" ]; then
      echo "cursor-project-hash: verify: OK agent-transcripts present under project dir" >&2
    else
      echo "cursor-project-hash: verify: note: agent-transcripts/ not present yet" >&2
    fi
  else
    echo "cursor-project-hash: verify: note: project dir not found (expected on fresh machines): $proj" >&2
  fi
}

main() {
  local verify=0
  local root_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --help | -h)
        usage
        exit 0
        ;;
      --verify)
        verify=1
        shift
        ;;
      -*)
        echo "cursor-project-hash: unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
      *)
        if [ -n "$root_arg" ]; then
          echo "cursor-project-hash: unexpected extra argument: $1" >&2
          exit 1
        fi
        root_arg="$1"
        shift
        ;;
    esac
  done

  local resolved="${root_arg:-${REPO_ROOT:-$DEFAULT_ROOT}}"
  local abs
  abs="$(canonical_root "$resolved")"
  local hash
  hash="$(encode_cursor_project_name "$abs")"
  printf '%s\n' "$hash"
  if [ "$verify" -eq 1 ]; then
    do_verify "$hash"
  fi
}

main "$@"
