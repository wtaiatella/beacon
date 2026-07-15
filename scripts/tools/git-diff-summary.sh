#!/usr/bin/env bash
# Produce a structured diff summary for a git repo: branch name, files changed,
# lines added/removed, uncommitted and committed changes since merge-base.
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <target-directory>"
  echo "  Structured summary of git changes vs default branch and working tree."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
  usage
  exit 0
fi

TARGET="$1"
if [[ ! -d "$TARGET" ]]; then
  echo "Error: not a directory: $TARGET" >&2
  exit 1
fi
cd "$TARGET"

if [[ ! -d .git ]]; then
  echo "Warning: Not a git repository: $TARGET" >&2
  exit 0
fi

branch=$(git rev-parse --abbrev-ref HEAD)
default=""
for ref in main master origin/main origin/master; do
  git rev-parse -q --verify "$ref" >/dev/null 2>&1 && { default=$ref; break; }
done
[[ -n "$default" ]] || default="HEAD"
mb=$(git merge-base HEAD "$default" 2>/dev/null || echo "")

echo "=== Git diff summary ==="
echo "Directory:  $TARGET"
echo "Branch:     $branch"
echo "Default:    ${default}"
echo "Merge-base: ${mb:-<none>}"

if [[ -n "$mb" ]]; then
  echo ""
  echo "--- Commits (merge-base..HEAD) ---"
  git log --oneline "${mb}..HEAD" 2>/dev/null || true
  echo ""
  echo "--- Files changed (committed: A/M/D) ---"
  git diff --name-status "${mb}..HEAD" 2>/dev/null || true
  echo ""
  echo "--- Diff stat (committed) ---"
  git diff --stat "${mb}..HEAD" 2>/dev/null || true
  read -r add del <<<"$(git diff --numstat "${mb}..HEAD" 2>/dev/null | awk '{a+=$1;d+=$2} END{print a+0, d+0}')"
  echo "Lines added/removed (committed): ${add:-0} / ${del:-0}"
fi

echo ""
echo "--- Uncommitted (working tree vs index + unstaged) ---"
git diff --name-status 2>/dev/null || true
git diff --cached --name-status 2>/dev/null || true
git diff --stat 2>/dev/null || true
git diff --cached --stat 2>/dev/null || true
read -r uadd udel <<<"$( (git diff --numstat; git diff --cached --numstat) 2>/dev/null | awk '{a+=$1;d+=$2} END{print a+0, d+0}')"
echo "Lines added/removed (uncommitted): ${uadd:-0} / ${udel:-0}"
