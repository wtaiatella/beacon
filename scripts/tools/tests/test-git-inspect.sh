#!/usr/bin/env bash
# Tests for git-inspect.sh (including --repo for ROAD-48 target inspection).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GI="$ROOT/scripts/tools/git-inspect.sh"
cd "$ROOT"

bash "$GI" --help | grep -q -- '--repo'

# Default: inspects orchestrator repo
bash "$GI" | grep -q "=== repo ==="
bash "$GI" | grep -q "^root: $ROOT$"

# --- --repo on a separate git clone ---
tmp=$(mktemp -d "${TMPDIR:-/tmp}/git-inspect-test.XXXXXX")
cleanup_tmp() { rm -rf "$tmp"; }
trap cleanup_tmp EXIT

git -C "$tmp" init -q
git -C "$tmp" config user.email "test@example.com"
git -C "$tmp" config user.name "test"
echo a >"$tmp/file.txt"
git -C "$tmp" add file.txt
git -C "$tmp" commit -q -m "init"
target_root=$(cd "$tmp" && pwd -P)

out=$(bash "$GI" --repo "$tmp")
printf '%s\n' "$out" | grep -q "^root: $target_root$"

# Invalid --repo: missing path
if bash "$GI" --repo "$tmp/nonexistent" 2>/dev/null; then
  echo "FAIL: expected non-zero for missing --repo path" >&2
  exit 1
fi

# Invalid --repo: directory exists but is not a git work tree
not_git=$(mktemp -d "${TMPDIR:-/tmp}/git-inspect-notgit.XXXXXX")
cleanup_ng() { rm -rf "$not_git"; }
trap 'cleanup_tmp; cleanup_ng' EXIT
if bash "$GI" --repo "$not_git" 2>/dev/null; then
  echo "FAIL: expected non-zero for non-git --repo" >&2
  exit 1
fi

echo "test-git-inspect: ok"
