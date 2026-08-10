#!/usr/bin/env bash
# format-on-edit — auto-format the edited file (Claude PostToolUse Write|Edit or
# Cursor afterFileEdit). Never blocks. Dual input path via lib/hook-protocol.js.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export HOOK_DIR="$DIR"
INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | node -e '
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
let input = {};
try { input = JSON.parse(require("fs").readFileSync(0, "utf8")); } catch (_) {}
process.stdout.write(proto.filePathOf(input));
')
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0
DIR_FILE=$(cd "$(dirname "$FILE_PATH")" && pwd)
EXT="${FILE_PATH##*.}"

if [ "$EXT" = "go" ] && command -v gofmt >/dev/null 2>&1; then
  gofmt -w "$FILE_PATH"
  exit 0
fi
if [ "$EXT" = "rs" ] && command -v rustfmt >/dev/null 2>&1; then
  rustfmt "$FILE_PATH"
  exit 0
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

[ -z "$ROOT" ] && exit 0
case "$EXT" in
  ts|tsx|js|jsx) (cd "$ROOT" && npx --yes prettier --write "$FILE_PATH") ;;
  py)
    if has_black "$ROOT"; then (cd "$ROOT" && black "$FILE_PATH")
    elif has_ruff_fmt "$ROOT"; then (cd "$ROOT" && ruff format "$FILE_PATH"); fi ;;
esac
exit 0
