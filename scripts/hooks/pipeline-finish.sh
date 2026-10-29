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
REPO_OVERRIDE=""
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
      echo "pipeline-finish: --repo is not a directory: $REPO_OVERRIDE" >&2
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
      echo "pipeline-finish: attach-target.txt must name an existing directory (ROAD-48); got: ${line:-<empty>}" >&2
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
          echo "pipeline-finish: ticket _state.json lists multiple repos (${state_repo#__MULTI__:}); pass --repo <dir> explicitly" >&2
          return 1
          ;;
      esac
      local repo_path="$state_repo"
      case "$repo_path" in
        /*) ;;
        *) repo_path="$ROOT/$repo_path" ;;
      esac
      if [ ! -d "$repo_path" ]; then
        echo "pipeline-finish: _state.json repo directory does not exist: $state_repo (resolved: $repo_path)" >&2
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
Usage: pipeline-finish.sh [--ticket <folder>] [--repo <dir>] [--no-commit]
                          [--commit-message <msg> | --commit-file <path>] [--push true|false]
                          [--pre-audit-delay-seconds <N>] [--] [extra-args for audit-session-trace.py ...]

  --ticket <folder>        Ticket folder path (workspace-relative).
  --repo <dir>             Override git root (else attach-target.txt > _state.json repo > workspace root).
  --no-commit              Do not run git add / git commit.
  --commit-message <msg>   If there are changes, run git add -A and git commit -m <msg>.
  --commit-file <path>     Like -m but uses git commit -F <path> (for messages with quotes/newlines).
  --push true|false        Default false. Push only if explicitly true (matches §9 explicit Yes).

Git root resolution order: --repo <dir> > <ticket>/_run/attach-target.txt > <ticket>/_state.json "repo"
field ($ROOT/<repo>) > orchestrator workspace root ($ROOT). If _state.json declares "repo" and that
directory does not exist, pipeline-finish exits with an error rather than silently falling back to $ROOT.

Mirrors Automatic commit execution: git status first; if nothing to commit when a commit was requested,
skip add/commit (exit 0 for that step).

After git: runs python3 on scripts/tools/audit-session-trace.py from the orchestrator root (session
paths and PROJECT_HASH behavior unchanged). Optional audit flags go after -- or as --pre-audit-delay-seconds.

Never pushes unless --push true, and refuses to push protected branches (main/master/develop/development/release/*).

Exit codes: invalid repo/attach-target → non-zero; git commit/push failure → non-zero; audit returns its own exit code (propagated).
EOF
}

NO_COMMIT=0
TICKET=""
REPO_OVERRIDE=""
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
    --repo)
      [ $# -ge 2 ] || { echo "pipeline-finish: --repo requires a path" >&2; exit 1; }
      REPO_OVERRIDE="$2"
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
  cur_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  case "$cur_branch" in
    main|master|develop|development|release/*)
      echo "pipeline-finish: refusing to push protected branch '$cur_branch' in $GIT_ROOT" >&2
      exit 1
      ;;
  esac
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
