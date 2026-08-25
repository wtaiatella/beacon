#!/usr/bin/env bash
# session-init — inject child-repo inventory, spec status, and session memory.
# Claude SessionStart + Cursor sessionStart. Dual output via lib/hook-protocol.js.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
export HOOK_DIR="$DIR"
export HOOK_INPUT="$(cat || true)"
mkdir -p "$ROOT/docs/sessions"

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
  REPOS_OUT="(none detected yet — clone target repos as subdirectories of the workspace root, e.g. git clone <url> myapp/)"
fi

# Keep Cursor/VS Code SCM discovery in sync (fail-open). Nested child repos are
# otherwise flaky to detect because the workspace root .gitignore uses "*".
if [ -f "$ROOT/scripts/tools/sync-vscode-git-repos.sh" ]; then
  bash "$ROOT/scripts/tools/sync-vscode-git-repos.sh" >/dev/null 2>&1 || true
fi

SESSION_META=""
if [ -f "$ROOT/scripts/tools/session-memory.sh" ]; then
  bash "$ROOT/scripts/tools/session-memory.sh" prune 2>/dev/null || true
  bash "$ROOT/scripts/tools/session-memory.sh" init 2>/dev/null || true
  AP=$(bash "$ROOT/scripts/tools/session-memory.sh" active-path 2>/dev/null) || AP=""
  AID=""
  if [ -f "$ROOT/docs/sessions/ACTIVE_SESSION" ]; then
    AID=$(head -n 1 "$ROOT/docs/sessions/ACTIVE_SESSION" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi
  if [ -n "$AID" ] && [ -n "$AP" ]; then
    SESSION_META="Session ID: ${AID}
Active session file (workspace-relative): ${AP}"
  elif [ -n "$AID" ]; then
    SESSION_META="Session ID: ${AID}"
  fi
fi

SPEC_OUT=""
if [ -f "$ROOT/scripts/tools/spec-status.sh" ]; then
  SPEC_OUT=$(bash "$ROOT/scripts/tools/spec-status.sh" 2>&1) || SPEC_OUT="${SPEC_OUT} (exit $?)"
else
  SPEC_OUT="Active specs in docs/specs/: (scripts/tools/spec-status.sh not found — run setup if applicable)"
fi

MEM_OUT=""
if [ -f "$ROOT/scripts/tools/session-memory.sh" ]; then
  MEM_OUT=$(bash "$ROOT/scripts/tools/session-memory.sh" read 2>&1) || MEM_OUT="${MEM_OUT} (exit $?)"
else
  MEM_OUT="(scripts/tools/session-memory.sh not found — run setup if applicable)"
fi

ACTIVE_HEADER="=== Active session ==="
if [ ! -f "$ROOT/scripts/tools/session-memory.sh" ]; then
  ACTIVE_BLOCK="${ACTIVE_HEADER}
(scripts/tools/session-memory.sh not found — run setup if applicable)"
else
  ACTIVE_BLOCK="${ACTIVE_HEADER}
${SESSION_META:-Session id not yet available; see docs/run-pipeline-reference.md (Session storage).}"
fi

COMBINED="=== Target repos in this multi-repo workspace ===
${REPOS_OUT}
=== Spec status ===
${SPEC_OUT}

${ACTIVE_BLOCK}

=== Session memory ===
${MEM_OUT}"

export HOOK_CONTEXT="$COMBINED"
node <<'NODE'
const proto = require(process.env.HOOK_DIR + "/lib/hook-protocol");
let input = {};
try {
  input = JSON.parse(process.env.HOOK_INPUT || "{}");
} catch (_) {}
proto.emitSessionStartContext(input, process.env.HOOK_CONTEXT || "");
NODE
