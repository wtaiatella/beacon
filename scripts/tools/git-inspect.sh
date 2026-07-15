#!/usr/bin/env bash
# Read-only git summary for run-pipeline orchestrator: branch, status, optional path-scoped
# diff stats, and ignore probes. Self-contained (does not call git-diff-summary.sh).
# Bash 3.2+ compatible.
set -euo pipefail
# Downstream may close stdout early (e.g. grep -q | head); avoid SIGPIPE failing scripts with pipefail.
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: git-inspect.sh [--repo <path>] [--path <path>] [--] [path ...]

  Optional path scope: restricts diff --stat / check-ignore to paths (workspace-relative or
  absolute). Multiple paths append to the same scope.

Stdout: fixed sections (see === headers below).

Options:
  --repo <dir> Inspect this git working tree (absolute or relative path). When set, all git
               commands run in the resolved repo root (ROAD-48 target repo for multi-root /run).
               Default: orchestrator repo (parent of scripts/tools/).
  --path <p>   Add one path to scope (repeatable).
  -h, --help   This help.

Runs from workspace root by default (override with --repo for branch consent on a target clone).
EOF
}

REPO_OPT=""
SCOPE=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      [ $# -ge 2 ] || { echo "git-inspect: --repo requires a value" >&2; exit 1; }
      REPO_OPT="$2"
      shift 2
      ;;
    --path)
      [ $# -ge 2 ] || { echo "git-inspect: --path requires a value" >&2; exit 1; }
      SCOPE+=("$2")
      shift 2
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do SCOPE+=("$1"); shift; done
      break
      ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "git-inspect: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      SCOPE+=("$1")
      shift
      ;;
  esac
done

ORCH_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -n "$REPO_OPT" ]; then
  if [ ! -d "$REPO_OPT" ]; then
    echo "git-inspect: --repo path is not a directory: $REPO_OPT" >&2
    exit 1
  fi
  ROOT="$(cd "$REPO_OPT" && pwd -P)"
else
  ROOT="$ORCH_ROOT"
fi

cd "$ROOT"

section() { printf '%s\n' "$1"; }

section "=== git-inspect ==="

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  section "error: not a git repository at $ROOT"
  exit 1
fi

# After fatal checks: downstream may close stdout early (grep -q, head); do not exit non-zero on EPIPE.
set +e

BR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
section "=== repo ==="
section "root: $ROOT"
section "branch: $BR"

section "=== path-scope ==="
if [ "${#SCOPE[@]}" -eq 0 ]; then
  section "(entire repo)"
else
  for p in "${SCOPE[@]}"; do
    section "$p"
  done
fi

section "=== status ==="
if [ "${#SCOPE[@]}" -eq 0 ]; then
  git status -sb 2>/dev/null || true
else
  git status -sb -- "${SCOPE[@]}" 2>/dev/null || true
fi

section "=== porcelain ==="
if [ "${#SCOPE[@]}" -eq 0 ]; then
  git status --porcelain 2>/dev/null || true
else
  git status --porcelain -- "${SCOPE[@]}" 2>/dev/null || true
fi

section "=== untracked-sample ==="
# Short list of untracked (if any) — capped
if [ "${#SCOPE[@]}" -eq 0 ]; then
  git ls-files --others --exclude-standard 2>/dev/null | head -n 50 || true
  UT_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
else
  git ls-files --others --exclude-standard -- "${SCOPE[@]}" 2>/dev/null | head -n 50 || true
  UT_COUNT=$(git ls-files --others --exclude-standard -- "${SCOPE[@]}" 2>/dev/null | wc -l | tr -d ' ')
fi
section "untracked-count: $UT_COUNT"

section "=== ignore-check ==="
if [ "${#SCOPE[@]}" -gt 0 ]; then
  for p in "${SCOPE[@]}"; do
    if git check-ignore -v -- "$p" 2>/dev/null; then
      :
    else
      section "not-ignored: $p"
    fi
  done
else
  section "(no paths — skipped; use --path for ignore probes)"
fi

section "=== diff-stat (unstaged) ==="
if [ "${#SCOPE[@]}" -eq 0 ]; then
  git diff --stat 2>/dev/null || true
else
  git diff --stat -- "${SCOPE[@]}" 2>/dev/null || true
fi

section "=== diff-stat (staged) ==="
if [ "${#SCOPE[@]}" -eq 0 ]; then
  git diff --cached --stat 2>/dev/null || true
else
  git diff --cached --stat -- "${SCOPE[@]}" 2>/dev/null || true
fi

section "=== git-inspect-done ==="

exit 0
