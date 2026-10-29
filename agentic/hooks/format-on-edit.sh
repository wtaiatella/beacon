#!/usr/bin/env bash
# format-on-edit — auto-format the edited file (Claude PostToolUse Write|Edit or
# Cursor afterFileEdit). Never blocks. Dual input path via lib/hook-protocol.js.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export HOOK_DIR="$DIR"
INPUT=$(cat || true)
export HOOK_INPUT="$INPUT"

finish() {
  node -e '
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const input = proto.readInput();
proto.postToolUseDone(input);
' 2>/dev/null || true
  exit 0
}

FILE_PATH=$(node -e '
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const input = proto.readInput();
process.stdout.write(proto.filePathOf(input));
' 2>/dev/null || true)
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  finish
fi
DIR_FILE=$(cd "$(dirname "$FILE_PATH")" && pwd)
EXT="${FILE_PATH##*.}"

if [ "$EXT" = "go" ] && command -v gofmt >/dev/null 2>&1; then
  gofmt -w "$FILE_PATH" >/dev/null 2>&1 || true
  finish
fi
if [ "$EXT" = "rs" ] && command -v rustfmt >/dev/null 2>&1; then
  rustfmt "$FILE_PATH" >/dev/null 2>&1 || true
  finish
fi

has_prettier() {
  local d="$1" f
  for f in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs prettier.config.js prettier.config.cjs; do
    [ -f "$d/$f" ] && return 0
  done
  [ -f "$d/package.json" ] && grep -q '"prettier"' "$d/package.json" 2>/dev/null
}
has_black() { [ -f "$1/pyproject.toml" ] && grep -q '^\[tool\.black\]' "$1/pyproject.toml" 2>/dev/null; }
has_ruff_fmt() { [ -f "$1/pyproject.toml" ] && grep -q '^\[tool\.ruff\]' "$1/pyproject.toml" 2>/dev/null; }

ROOT=""
d="$DIR_FILE"
while [ "$d" != "/" ]; do
  case "$EXT" in
    ts|tsx|js|jsx) has_prettier "$d" && { ROOT="$d"; break; } ;;
    py) (has_black "$d" || has_ruff_fmt "$d") && { ROOT="$d"; break; } ;;
  esac
  d=$(dirname "$d")
done

if [ -z "$ROOT" ]; then
  finish
fi
case "$EXT" in
  ts|tsx|js|jsx) (cd "$ROOT" && npx --yes prettier --write "$FILE_PATH" >/dev/null 2>&1 || true) ;;
  py)
    if has_black "$ROOT"; then (cd "$ROOT" && black "$FILE_PATH" >/dev/null 2>&1 || true)
    elif has_ruff_fmt "$ROOT"; then (cd "$ROOT" && ruff format "$FILE_PATH" >/dev/null 2>&1 || true); fi ;;
esac
finish
