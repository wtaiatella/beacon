#!/usr/bin/env bash
# Mid-pipeline commit helper for run-pipeline commit_policy (per_task / per_phase).
# git add + git commit only — never push, never session-trace audit (those stay in pipeline-finish.sh §9).
# Bash 3.2+ compatible.
set -euo pipefail
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TICKET=""
ATTACH_TARGET_NAME="attach-target.txt"

# Git root resolution order:
# 1. --repo <dir>
# 2. <ticket>/_run/attach-target.txt
# 3. <ticket>/_state.json field "repo" (or single-element "repos")
# 4. $ROOT (only when no ticket repo is declared)
resolve_git_root() {
  if [ -n "$REPO_OVERRIDE" ]; then
    local target_dir="$REPO_OVERRIDE"
    case "$target_dir" in
      /*) ;;
      *) [ -d "$target_dir" ] || target_dir="$ROOT/$target_dir" ;;
    esac
    if [ ! -d "$target_dir" ]; then
      echo "pipeline-commit: --repo is not a directory: $REPO_OVERRIDE" >&2
      return 1
    fi
    (cd "$target_dir" && pwd -P)
    return 0
  fi
  if [ -z "$TICKET" ]; then
    printf '%s\n' "$ROOT"
    return 0
  fi
  local attach_file line gr state_file state_repo
  attach_file="$ROOT/$TICKET/_run/$ATTACH_TARGET_NAME"
  if [ -f "$attach_file" ]; then
    line=$(head -n 1 "$attach_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$line" ] || [ ! -d "$line" ]; then
      echo "pipeline-commit: attach-target.txt must name an existing directory (ROAD-48); got: ${line:-<empty>}" >&2
      return 1
    fi
    gr=$(cd "$line" && pwd -P)
    printf '%s\n' "$gr"
    return 0
  fi
  state_file="$ROOT/$TICKET/_state.json"
  if [ -f "$state_file" ]; then
    state_repo=$(python3 -c '
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
r = data.get("repo") or data.get("repos")
if isinstance(r, str) and r.strip():
    print(r.strip())
elif isinstance(r, list):
    items = [str(x).strip() for x in r if str(x).strip()]
    if len(items) == 1:
        print(items[0])
    elif len(items) > 1:
        print("__MULTI__:" + ",".join(items))
' "$state_file" 2>/dev/null || true)
    if [ -n "$state_repo" ]; then
      case "$state_repo" in
        __MULTI__:*)
          echo "pipeline-commit: ticket _state.json lists multiple repos (${state_repo#__MULTI__:}); pass --repo <dir> explicitly" >&2
          return 1
          ;;
      esac
      local repo_path="$state_repo"
      case "$repo_path" in
        /*) ;;
        *) repo_path="$ROOT/$repo_path" ;;
      esac
      if [ ! -d "$repo_path" ]; then
        echo "pipeline-commit: _state.json repo directory does not exist: $state_repo (resolved: $repo_path)" >&2
        return 1
      fi
      gr=$(cd "$repo_path" && pwd -P)
      printf '%s\n' "$gr"
      return 0
    fi
  fi
  printf '%s\n' "$ROOT"
}

usage() {
  cat <<'EOF'
Usage: pipeline-commit.sh --commit-message <msg> | --commit-file <path>
                          [--ticket <folder>] [--repo <dir>]

  Mid-pipeline commit only (run-pipeline commit_policy). No push. No audit.

  --commit-message <msg>   git add -A && git commit -m <msg> when dirty.
  --commit-file <path>     Same with git commit -F <path>.
  --ticket <folder>        Ticket folder path (workspace-relative).
  --repo <dir>             Override git root (else attach-target.txt > _state.json repo > orchestrator root).

If the working tree is clean, skips add/commit and exits 0.

Exit: invalid repo/attach-target or commit hook failure → non-zero.
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
    --ticket)
      [ $# -ge 2 ] || { echo "pipeline-commit: --ticket requires a value" >&2; exit 1; }
      TICKET="$2"
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

GIT_ROOT="$(resolve_git_root)" || exit 1

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
