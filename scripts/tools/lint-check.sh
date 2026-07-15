#!/usr/bin/env bash
# Auto-detect linter in a target directory and run checks.
# After changing to TARGET:
#   1) scans .cursor/agents, .cursor/skills, .cursor/rules for ROAD-<digits> (when those dirs exist).
#   2) scans .cursor/agents/*.md for MCP toolbox leakage (see check_no_mcp_in_non_specialists).
# Then runs language linters: eslint, ruff, flake8, golangci-lint, cargo clippy.
#
# Simulating failures locally (integration tests under scripts/tools/tests/):
#   - Clean tree at repo root must pass: ./scripts/tools/tests/test-lint-check-repo-root.sh
#   - ROAD-ID guard (isolated tmp): ./scripts/tools/tests/test-lint-check-road-guard.sh
#   - Subagent shell patterns (isolated tmp): ./scripts/tools/tests/test-lint-check-subagent-shell-patterns.sh
#   - Roadmap/spec sync: ./scripts/tools/tests/test-lint-check-roadmap-spec-sync.sh
#   - Root session symlink guard (ROAD-53; only when TARGET is the git repo root):
#       ln -sfn "$(pwd)/docs/sessions" ./_lint-symlink-violation-test
#       ./scripts/tools/lint-check.sh .   # expect non-zero
#       rm -f ./_lint-symlink-violation-test
#     (Use a name not in .gitignore if you need the symlink to exist on disk for the probe;
#      remove before commit.)
#
# Status-Sync (verify-roadmap-spec-sync.sh): when docs/specs and docs/roadmaps exist under
# TARGET, verifies completed specs align with ROAD-NN roadmap files (ROAD-45).
#
# MCP guard (check_no_mcp_in_non_specialists):
# Only these agent files may mention the patterns below (implementation-tier and most personas must
# route enterprise context via REQUEST_MAIN / orchestrator Task(mcp-*), not direct tool marketing):
#   - mcp-*.md, plan.md, pre-plan-triage.md
# Forbidden in all other .cursor/agents/*.md (case-insensitive where noted):
#   - "Optional MCP" — optional-toolbox bullets that invite direct MCP use from non-specialists.
#   - "call_mcp_tool" — Cursor MCP tool invocation hook name.
#   - "MCP server" / "MCP servers" — generic MCP server product phrasing (orchestration prose may use
#     Task(mcp-*) or specialist names; those are not matched here).
#
# Subagent shell / rogue-instruction guard (ROAD-55; scripts/tools/lint-subagent-prompt-patterns.py):
# Scans .cursor/agents/*.md and .cursor/skills/**/*.md only (not .cursor/rules/ or scripts/tools/).
# Fails on forbidden substrings outside markdown fences when the line is not exempt:
#   - python3 -c, git mv, git commit, awk '{
# Exemptions (see script docstring and CONTRIBUTING.md): fenced ``` blocks; lines with
# <!-- lint:allow-subagent-shell -->; first-party script paths (pipeline-finish, git-inspect.sh,
# archive-roadmap.sh, query-transcript.py, audit-session-trace); or clear prohibition/negation prose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $(basename "$0") <target-directory>"
  echo "  Auto-detects a linter in the directory and runs checks."
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

# Repository-root symlinks must not point into docs/sessions/ (ROAD-53 workspace cleanliness).
check_no_root_session_symlinks() {
  local toplevel here sessions_abs resolved offenders="" link
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi
  if ! toplevel=$(git rev-parse --show-toplevel 2>/dev/null); then
    return 0
  fi
  here=$(pwd -P)
  if [[ "$here" != "$(cd "$toplevel" && pwd -P)" ]]; then
    return 0
  fi
  export LINT_REPO_ROOT="$here"
  sessions_abs=$(python3 -c 'import os; print(os.path.realpath(os.path.join(os.environ["LINT_REPO_ROOT"], "docs", "sessions")))' 2>/dev/null) || {
    unset LINT_REPO_ROOT
    return 0
  }
  unset LINT_REPO_ROOT
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    export LINT_SYMLINK_CHECK_PATH="$link"
    resolved=$(python3 -c 'import os; print(os.path.realpath(os.environ["LINT_SYMLINK_CHECK_PATH"]))' 2>/dev/null) || {
      unset LINT_SYMLINK_CHECK_PATH
      continue
    }
    unset LINT_SYMLINK_CHECK_PATH
    if [[ "$resolved" == "$sessions_abs"/* ]] || [[ "$resolved" == "$sessions_abs" ]]; then
      offenders+="  $link -> $resolved"$'\n'
    fi
  done < <(find . -maxdepth 1 -type l 2>/dev/null)
  if [[ -n "$offenders" ]]; then
    echo "Error: Repository root must not contain symlinks whose target resolves under docs/sessions/ (ROAD-53). Offenders:" >&2
    printf '%s' "$offenders" >&2
    return 1
  fi
  return 0
}

# Historical initiative IDs (ROAD-<digits>) must not appear in permanent prompt trees.
# Paths are relative to TARGET (e.g. ./scripts/tools/lint-check.sh . from repo root).
check_no_road_tracking_ids() {
  local d found=0
  for d in .cursor/agents .cursor/skills .cursor/rules; do
    if [[ ! -d "$d" ]]; then
      continue
    fi
    set +e
    # -I: skip binary files (portable BSD/GNU). Pattern: ROAD- then one or more digits.
    output=$(grep -rIEn 'ROAD-[0-9]+' "$d" 2>/dev/null)
    rc=$?
    set -e
    if [[ $rc -eq 2 ]]; then
      echo "Error: scan failed for $d (grep error)." >&2
      return 1
    fi
    if [[ $rc -eq 0 && -n "$output" ]]; then
      printf '%s\n' "$output"
      found=1
    fi
  done
  if [[ $found -ne 0 ]]; then
    echo "Error: Historical tracking IDs (ROAD-<digits>) must not appear under .cursor/agents/, .cursor/skills/, or .cursor/rules/. See CONTRIBUTING.md (No Historical Tracking IDs in Prompts)." >&2
    return 1
  fi
  return 0
}

check_no_mcp_in_non_specialists() {
  local agents_dir=".cursor/agents"
  if [[ ! -d "$agents_dir" ]]; then
    return 0
  fi
  local f base found=0 output rc
  shopt -s nullglob
  for f in "$agents_dir"/*.md; do
    base=$(basename "$f")
    if [[ "$base" == plan.md || "$base" == pre-plan-triage.md || "$base" =~ ^mcp- ]]; then
      continue
    fi
    set +e
    output=$(grep -nEi 'Optional MCP|call_mcp_tool|MCP servers?' "$f" 2>/dev/null)
    rc=$?
    set -e
    if [[ $rc -eq 2 ]]; then
      echo "Error: MCP scan failed for $f (grep error)." >&2
      return 1
    fi
    if [[ $rc -eq 0 && -n "$output" ]]; then
      printf '%s\n' "$output"
      found=1
    fi
  done
  shopt -u nullglob
  if [[ $found -ne 0 ]]; then
    echo "Error: Disallowed MCP toolbox patterns in .cursor/agents/*.md (only mcp-*.md, plan.md, pre-plan-triage.md may contain them). See script header in scripts/tools/lint-check.sh and CONTRIBUTING.md." >&2
    return 1
  fi
  return 0
}

check_no_root_session_symlinks || exit 1
check_no_road_tracking_ids
check_no_mcp_in_non_specialists

# ROAD-55: no instructional inline shell one-liners in permanent agent/skill prompts.
if [[ -d ".cursor/agents" || -d ".cursor/skills" ]]; then
  python3 "$SCRIPT_DIR/lint-subagent-prompt-patterns.py" "$(pwd)" || exit 1
fi

# ROAD-45: completed specs must match archived roadmap items (no ghost backlog).
if [[ -d "docs/specs" && -d "docs/roadmaps" ]]; then
  "$SCRIPT_DIR/verify-roadmap-spec-sync.sh" --root "$(pwd)" || exit 1
fi

has_eslint_config() {
  compgen -G '.eslintrc*' >/dev/null 2>&1 || compgen -G 'eslint.config.*' >/dev/null 2>&1
}

pyproject_has_ruff() {
  [[ -f pyproject.toml ]] && grep -qE '^\[tool\.ruff\]' pyproject.toml 2>/dev/null
}

pyproject_has_flake8() {
  [[ -f pyproject.toml ]] && grep -qE '^\[tool\.flake8\]' pyproject.toml 2>/dev/null
}

if has_eslint_config; then
  npx eslint .
elif pyproject_has_ruff; then
  ruff check .
elif pyproject_has_flake8; then
  flake8
elif [[ -f .golangci.yml ]] || [[ -f .golangci.yaml ]]; then
  golangci-lint run
elif [[ -f Cargo.toml ]]; then
  cargo clippy -- -D warnings 2>/dev/null || cargo clippy
else
  echo "Warning: No linter detected in $TARGET" >&2
  exit 0
fi
