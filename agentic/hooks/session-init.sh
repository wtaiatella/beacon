#!/usr/bin/env bash
# session-init — inject child-repo inventory, WORKSPACE.md (Cursor and
# Antigravity), and the spec-folder table.
# Claude already inlines WORKSPACE.md via @WORKSPACE.md in CLAUDE.md, so this
# hook does not print it again on a Claude SessionStart.
# Claude SessionStart + Cursor sessionStart + Antigravity PreInvocation.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat || true)"

META=$(node -e '
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
const input = proto.readInput();
const root = proto.workspaceRootOf(input, "");
const ide = proto.ideOf(input);
process.stdout.write(String(root) + "\n" + String(ide) + "\n");
' 2>/dev/null || true)
WS_ROOT=$(printf '%s\n' "$META" | sed -n '1p')
IDE=$(printf '%s\n' "$META" | sed -n '2p')

# Payload root wins. Otherwise walk up from the script until the workspace
# that contains scripts/tools/spec-status.sh. The installed Cursor copy lives
# at .cursor/hooks/beacon/, three levels down; DIR/../.. lands in .cursor.
ROOT=""
if [ -n "$WS_ROOT" ] && [ -d "$WS_ROOT" ]; then
  ROOT="$WS_ROOT"
else
  walk="$DIR"
  while [ -n "$walk" ] && [ "$walk" != "/" ]; do
    if [ -f "$walk/scripts/tools/spec-status.sh" ]; then
      ROOT="$walk"
      break
    fi
    parent="$(dirname "$walk")"
    [ "$parent" = "$walk" ] && break
    walk="$parent"
  done
fi
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$DIR/../.." && pwd)"
fi

REPOS_OUT=""
for d in "$ROOT"/*/; do
  [ -e "$d/.git" ] || continue
  name="$(basename "$d")"
  branch="$(git -C "$d" branch --show-current 2>/dev/null | head -1)"
  if [ -z "$branch" ]; then
    branch="$(git -C "$d" rev-parse --short HEAD 2>/dev/null | head -1)"
    [ -n "$branch" ] && branch="detached@${branch}" || branch="unknown"
  fi
  REPOS_OUT="${REPOS_OUT}- ${name}/ (branch: ${branch})
"
done
if [ -z "$REPOS_OUT" ]; then
  REPOS_OUT="(none detected yet — clone target repos as subdirectories of the workspace root, e.g. git clone <url> myapp/)
"
fi

# Keep Cursor/VS Code SCM discovery in sync (fail-open). Nested child repos are
# otherwise flaky to detect because the workspace root .gitignore uses "*".
if [ -f "$ROOT/scripts/tools/sync-vscode-git-repos.sh" ]; then
  bash "$ROOT/scripts/tools/sync-vscode-git-repos.sh" >/dev/null 2>&1 || true
fi

SPEC_OUT=""
if [ -f "$ROOT/scripts/tools/spec-status.sh" ]; then
  SPEC_OUT=$(bash "$ROOT/scripts/tools/spec-status.sh" 2>&1) || SPEC_OUT="${SPEC_OUT} (exit $?)"
else
  SPEC_OUT="No ticket folders in docs/specs/. (scripts/tools/spec-status.sh not found — run setup if applicable)"
fi

# Claude's CLAUDE.md already @-imports WORKSPACE.md. Printing it here would
# duplicate the contract. Empty stdin (a manual run) still prints the file.
PRINT_WS=1
if [ -n "$HOOK_INPUT" ] && [ "$HOOK_INPUT" != "{}" ] && [ "$IDE" = "claude" ]; then
  PRINT_WS=0
fi

WS_BLOCK=""
if [ "$PRINT_WS" -eq 1 ]; then
  WS_FILE="$ROOT/WORKSPACE.md"
  if [ ! -f "$WS_FILE" ]; then
    WS_BLOCK="=== Workspace contract ===
WORKSPACE.md is not in the workspace root."
  else
    size=$(wc -c < "$WS_FILE" | tr -d ' ')
    cap=32768
    if [ "$size" -gt "$cap" ]; then
      body=$(head -c 24576 "$WS_FILE")
      WS_BLOCK="=== Workspace contract (WORKSPACE.md) ===
${body}

WORKSPACE.md truncated (file is ${size} bytes at WORKSPACE.md)."
    else
      body=$(cat "$WS_FILE")
      WS_BLOCK="=== Workspace contract (WORKSPACE.md) ===
${body}"
    fi
  fi
fi

COMBINED="=== Target repos in this multi-repo workspace ===
${REPOS_OUT}"
if [ -n "$WS_BLOCK" ]; then
  COMBINED="${COMBINED}
${WS_BLOCK}
"
fi
COMBINED="${COMBINED}
=== Spec status ===
${SPEC_OUT}"

export HOOK_CONTEXT="$COMBINED"
node <<'NODE'
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
let input = {};
try {
  input = JSON.parse(process.env.HOOK_INPUT || "{}");
} catch (_) {}
proto.emitSessionStartContext(input, process.env.HOOK_CONTEXT || "");
NODE
