#!/usr/bin/env bash
# Mid-pipeline commit helper for run-pipeline commit_policy (per_task / per_phase).
# git add + git commit only — never push, never session-trace audit (those stay in pipeline-finish.sh §9).
# Bash 3.2+ compatible.
set -euo pipefail
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ACTIVE_SESSION_FILE="$ROOT/docs/sessions/ACTIVE_SESSION"
ATTACH_TARGET_NAME="attach-target.txt"

# Same ROAD-48 attach-target resolution as pipeline-finish.sh
resolve_git_root() {
  if [ ! -f "$ACTIVE_SESSION_FILE" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  local id
  id=$(head -n 1 "$ACTIVE_SESSION_FILE" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "${id:-}" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  case "$id" in
    *..*|*/*|*\\*)
      printf '%s\n' "$ROOT"
      return 0
      ;;
  esac
  local attach_file line gr
  attach_file="$ROOT/docs/sessions/$id/$ATTACH_TARGET_NAME"
  if [ ! -f "$attach_file" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  line=$(head -n 1 "$attach_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$line" ] || [ ! -d "$line" ]; then
    echo "pipeline-commit: attach-target.txt must name an existing directory (ROAD-48); got: ${line:-<empty>}" >&2
    return 1
  fi
  gr=$(cd "$line" && pwd -P)
  printf '%s\n' "$gr"
}

usage() {
  cat <<'EOF'
Usage: pipeline-commit.sh --commit-message <msg> | --commit-file <path>
                          [--repo <dir>]

  Mid-pipeline commit only (run-pipeline commit_policy). No push. No audit.

  --commit-message <msg>   git add -A && git commit -m <msg> when dirty.
  --commit-file <path>     Same with git commit -F <path>.
  --repo <dir>             Override git root (else attach-target / orchestrator root).

If the working tree is clean, skips add/commit and exits 0.

Exit: attach-target invalid or commit hook failure → non-zero.
EOF
}

COMMIT_MSG=""
COMMIT_FILE=""
REPO_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --commit-message)
      [ $# -ge 2 ] || { echo "pipeline-commit: --commit-message requires a value" >&2; exit 1; }
      COMMIT_MSG="$2"
      shift 2
      ;;
    --commit-file)
      [ $# -ge 2 ] || { echo "pipeline-commit: --commit-file requires a path" >&2; exit 1; }
      COMMIT_FILE="$2"
      shift 2
      ;;
    --repo)
      [ $# -ge 2 ] || { echo "pipeline-commit: --repo requires a path" >&2; exit 1; }
      REPO_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "pipeline-commit: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$COMMIT_MSG" ] && [ -z "$COMMIT_FILE" ]; then
  echo "pipeline-commit: require --commit-message or --commit-file" >&2
  usage >&2
  exit 1
fi
if [ -n "$COMMIT_MSG" ] && [ -n "$COMMIT_FILE" ]; then
  echo "pipeline-commit: use only one of --commit-message or --commit-file" >&2
  exit 1
fi

if [ -n "$COMMIT_FILE" ]; then
  case "$COMMIT_FILE" in
    /*) ;;
    *) COMMIT_FILE="$ROOT/$COMMIT_FILE" ;;
  esac
fi

if [ -n "$REPO_OVERRIDE" ]; then
  if [ ! -d "$REPO_OVERRIDE" ]; then
    echo "pipeline-commit: --repo is not a directory: $REPO_OVERRIDE" >&2
    exit 1
  fi
  GIT_ROOT=$(cd "$REPO_OVERRIDE" && pwd -P)
else
  GIT_ROOT="$(resolve_git_root)" || exit 1
fi

set +e
echo "=== pipeline-commit ==="
echo "=== git-root ==="
echo "$GIT_ROOT"
echo "=== git-status (brief) ==="
cd "$GIT_ROOT"
git status -sb || true

if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "=== commit ==="
  echo "Nothing to commit (working tree clean); skipping."
  echo "=== pipeline-commit-done ==="
  exit 0
fi

echo "=== git-add-commit ==="
git add -A || exit 1
if [ -n "$COMMIT_FILE" ]; then
  git commit -F "$COMMIT_FILE" || exit 1
else
  git commit -m "$COMMIT_MSG" || exit 1
fi
echo "=== pipeline-commit-done ==="
exit 0
