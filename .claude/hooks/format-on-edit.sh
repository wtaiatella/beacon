#!/usr/bin/env bash
# PostToolUse (matcher: Write|Edit) — auto-format the edited file using the
# project's formatter. Reads the tool call JSON from stdin; the edited path is at
# .tool_input.file_path. Walks up the directory tree to find the nearest project
# root and its formatter (Prettier, Black, Ruff, gofmt, rustfmt). No-op if no
# formatter applies or the file type is unsupported. Never blocks (exit 0).
set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | node -e "
try {
  const j = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  const ti = j.tool_input || {};
  process.stdout.write(ti.file_path || ti.filePath || '');
} catch (_) {}
")
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0
DIR=$(cd "$(dirname "$FILE_PATH")" && pwd)
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
d="$DIR"
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
