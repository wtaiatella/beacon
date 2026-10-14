#!/usr/bin/env bash
# Clone a target repository into the workspace root so it joins the dynamically
# detected repo inventory (see .claude/hooks/session-init.sh). The workspace's
# .gitignore tracks everything by default (project files, specs, knowledge),
# so each cloned child repo must be explicitly ignored — this script appends
# a `/<dir>/` entry to .gitignore on every successful clone. Used by /clone.
#
# Usage: clone-repo.sh <git-ssh-or-https-url> [target-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

URL="${1:-}"
DIR="${2:-}"

if [ -z "$URL" ]; then
  echo "Usage: clone-repo.sh <git-ssh-or-https-url> [target-dir]" >&2
  exit 2
fi

# Derive the default target dir from the URL: drop trailing .git, take last segment.
if [ -z "$DIR" ]; then
  DIR="$(basename "${URL%.git}")"
fi

# Safety: the clone must land in a plain subdirectory of the workspace root.
case "$DIR" in
  ""|.|..) echo "Invalid target dir: '$DIR'" >&2; exit 2 ;;
  /*|*/*|*..*) echo "Refusing suspicious target dir: '$DIR' (must be a single folder name under the workspace root)" >&2; exit 2 ;;
esac

if [ -e "$ROOT/$DIR" ]; then
  echo "Target '$DIR/' already exists — refusing to overwrite. Pass a different target dir." >&2
  exit 1
fi

echo "Cloning $URL -> $DIR/ ..."
git clone "$URL" "$DIR"

BRANCH="$(git -C "$ROOT/$DIR" branch --show-current 2>/dev/null | head -1)"
[ -z "$BRANCH" ] && BRANCH="unknown"

echo ""
echo "✓ Cloned '$DIR/' (branch: $BRANCH)"
echo "It is now part of the workspace's target-repo inventory (auto-detected on session start)."

# Register the new child repo in .gitignore (workspace tracks everything by
# default; each cloned repo is its own git history and must be excluded
# explicitly — idempotent, appends once per directory name).
GITIGNORE="$ROOT/.gitignore"
IGNORE_LINE="/$DIR/"
if [ -f "$GITIGNORE" ] && ! grep -Fxq "$IGNORE_LINE" "$GITIGNORE"; then
  printf '%s\n' "$IGNORE_LINE" >> "$GITIGNORE"
  echo "Added '$IGNORE_LINE' to .gitignore (child repo, excluded from this workspace's history)."
fi

# Register in Cursor/VS Code Source Control (git.scanRepositories). Nested
# repos otherwise don't show up in the SCM panel on their own.
if [ -f "$ROOT/scripts/tools/sync-vscode-git-repos.sh" ]; then
  bash "$ROOT/scripts/tools/sync-vscode-git-repos.sh" || true
  echo "Registered '$DIR/' in .vscode/settings.json → git.scanRepositories (Reload Window if SCM does not list it yet)."
fi

echo ""
echo "Current target repos:"
FOUND=0
for d in "$ROOT"/*/; do
  [ -e "$d/.git" ] || continue
  n="$(basename "$d")"
  b="$(git -C "$d" branch --show-current 2>/dev/null | head -1)"; [ -z "$b" ] && b="unknown"
  echo "- $n/ (branch: $b)"
  FOUND=1
done
if [ "$FOUND" -eq 0 ]; then
  echo "(none)"
fi
