#!/usr/bin/env bash
# run-pipeline §9 Finish — optional git add/commit, optional push (only when explicitly requested),
# then audit-session-trace.py with skill-documented defaults (audit always resolves orchestrator paths
# from the repo root; see scripts/tools/audit-session-trace.py).
# Bash 3.2+ compatible.
set -euo pipefail
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_PY="$ROOT/scripts/tools/audit-session-trace.py"
TICKET=""
ATTACH_TARGET_NAME="attach-target.txt"

# When <ticket>/_run/attach-target.txt names a directory, git add/commit/push run there.
resolve_git_root() {
  if [ -z "$TICKET" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  local attach_file line gr
  attach_file="$ROOT/$TICKET/_run/$ATTACH_TARGET_NAME"
  if [ ! -f "$attach_file" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  line=$(head -n 1 "$attach_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$line" ] || [ ! -d "$line" ]; then
    echo "pipeline-finish: attach-target.txt must name an existing directory (ROAD-48); got: ${line:-<empty>}" >&2
    return 1
  fi
  gr=$(cd "$line" && pwd -P)
  printf '%s\n' "$gr"
}

usage() {
  cat <<'EOF'
Usage: pipeline-finish.sh [--no-commit] [--commit-message <msg> | --commit-file <path>] [--push true|false]
                          [--pre-audit-delay-seconds <N>] [--] [extra-args for audit-session-trace.py ...]

  --no-commit              Do not run git add / git commit.
  --commit-message <msg>   If there are changes, run git add -A and git commit -m <msg>.
  --commit-file <path>     Like -m but uses git commit -F <path> (for messages with quotes/newlines).
  --push true|false        Default false. Push only if explicitly true (matches §9 explicit Yes).

Git steps run in the orchestrator workspace root by default. When --ticket is set and
<ticket>/_run/attach-target.txt exists, git add/commit/push run in the target directory named on the first line;
if that path is missing or not a directory, pipeline-finish exits with an error before git.

Mirrors Automatic commit execution: git status first; if nothing to commit when a commit was requested,
skip add/commit (exit 0 for that step).

After git: runs python3 on scripts/tools/audit-session-trace.py from the orchestrator root (session
paths and PROJECT_HASH behavior unchanged). Optional audit flags go after -- or as --pre-audit-delay-seconds.

Never pushes unless --push true.

Exit codes: attach-target invalid → non-zero; git commit hook failure → non-zero; audit returns its own exit code (propagated).
EOF
}

NO_COMMIT=0
TICKET=""
COMMIT_MSG=""
COMMIT_FILE=""
PUSH="false"
PRE_AUDIT_DELAY=""

EXTRA_AUDIT=()
end_of_opts=0
while [ $# -gt 0 ]; do
  if [ "$end_of_opts" -eq 1 ]; then
    EXTRA_AUDIT+=("$1")
    shift
    continue
  fi
  case "$1" in
    --) end_of_opts=1; shift ;;
    --ticket)
      [ $# -ge 2 ] || { echo "pipeline-finish: --ticket requires a value" >&2; exit 1; }
      TICKET="$2"
      shift 2
      ;;
    --no-commit) NO_COMMIT=1; shift ;;
    --commit-message)
      [ $# -ge 2 ] || { echo "pipeline-finish: --commit-message requires a value" >&2; exit 1; }
      COMMIT_MSG="$2"
      shift 2
      ;;
    --commit-file)
      [ $# -ge 2 ] || { echo "pipeline-finish: --commit-file requires a path" >&2; exit 1; }
      COMMIT_FILE="$2"
      shift 2
      ;;
    --push)
      [ $# -ge 2 ] || { echo "pipeline-finish: --push requires true or false" >&2; exit 1; }
      case "$2" in
        true|false) PUSH="$2" ;;
        *) echo "pipeline-finish: --push must be true or false" >&2; exit 1 ;;
      esac
      shift 2
      ;;
    --pre-audit-delay-seconds)
      [ $# -ge 2 ] || { echo "pipeline-finish: --pre-audit-delay-seconds requires a number" >&2; exit 1; }
      PRE_AUDIT_DELAY="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "pipeline-finish: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -n "$COMMIT_MSG" ] && [ -n "$COMMIT_FILE" ]; then
  echo "pipeline-finish: use only one of --commit-message or --commit-file" >&2
  exit 1
fi
if [ "$NO_COMMIT" -eq 1 ] && { [ -n "$COMMIT_MSG" ] || [ -n "$COMMIT_FILE" ]; }; then
  echo "pipeline-finish: --no-commit conflicts with commit options" >&2
  exit 1
fi

# Commit message file is often workspace-relative to the orchestrator; resolve before cd to target.
if [ -n "$COMMIT_FILE" ]; then
  case "$COMMIT_FILE" in
    /*) ;;
    *) COMMIT_FILE="$ROOT/$COMMIT_FILE" ;;
  esac
fi

GIT_ROOT="$(resolve_git_root)" || exit 1
# Echo to closed stdout (e.g. cmd | head) must not fail the script.
set +e

echo "=== pipeline-finish ==="
echo "=== git-root ==="
echo "$GIT_ROOT"
echo "=== git-status (brief) ==="
cd "$GIT_ROOT"
git status -sb || true

if [ "$NO_COMMIT" -eq 0 ] && { [ -n "$COMMIT_MSG" ] || [ -n "$COMMIT_FILE" ]; }; then
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    echo "=== commit ==="
    echo "Nothing to commit (working tree clean); skipping git add / git commit."
  else
    echo "=== git-add-commit ==="
    git add -A || exit 1
    if [ -n "$COMMIT_FILE" ]; then
      git commit -F "$COMMIT_FILE" || exit 1
    else
      git commit -m "$COMMIT_MSG" || exit 1
    fi
  fi
elif [ "$NO_COMMIT" -eq 1 ]; then
  echo "=== commit ==="
  echo "Skipped (--no-commit)."
else
  echo "=== commit ==="
  echo "No commit message provided; skipping git add / git commit (use --commit-message or --commit-file, or --no-commit)."
fi

echo "=== git-push ==="
if [ "$PUSH" = "true" ]; then
  git push || exit 1
else
  echo "Skipped (push not requested; use --push true for explicit push)."
fi

echo "=== audit-session-trace ==="
cd "$ROOT"
AUDIT_CMD=(python3 "$AUDIT_PY")
if [ -n "$TICKET" ]; then
  AUDIT_CMD+=(--ticket "$TICKET")
fi
if [ -n "$PRE_AUDIT_DELAY" ]; then
  AUDIT_CMD+=(--pre-audit-delay-seconds "$PRE_AUDIT_DELAY")
fi
if [ "${#EXTRA_AUDIT[@]}" -gt 0 ]; then
  AUDIT_CMD+=("${EXTRA_AUDIT[@]}")
fi
"${AUDIT_CMD[@]}"
AUDIT_EXIT=$?
echo "=== pipeline-finish-done (audit exit $AUDIT_EXIT) ==="
exit "$AUDIT_EXIT"
