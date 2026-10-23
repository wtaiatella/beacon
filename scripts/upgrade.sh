#!/usr/bin/env bash
# Upgrade the framework source from the upstream remote, then reinstall IDE copies.
# Requires a git remote named "upstream" (a consumer workspace).
#
# This does not merge upstream/main and does not stash the worktree. Install
# trees (.cursor, .claude, .agents, plugins) and project skills outside beacon/
# are left to the installer. Only the framework source paths below are updated.
#
# "Up to date" is the commit hash recorded in agentic/.upgrade-state after the
# last successful --apply, compared with upstream/main. It is not a count of
# commits missing from this branch's history.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="default"
STATE_FILE="$ROOT/agentic/.upgrade-state"

# Source that setup copies into IDE runtimes. scripts/ is included because the
# installer and the tools it does not copy (pipeline hooks, spec-status, …)
# live there; the running upgrade.sh is already loaded, so refreshing the file
# only affects the next run. Install directories are not in this list.
FRAMEWORK_PATHS=(
  agentic
  scripts/setup-agentic.sh
  scripts/upgrade.sh
  scripts/hooks
  scripts/tools
)

usage() {
  cat <<'EOF'
Usage: upgrade.sh [option]

  Update framework source from the upstream remote, then reinstall IDE copies.
  Does not merge upstream/main and does not stash or commit the worktree.
  Project files, including .cursor paths outside beacon/, are not touched.

  The applied version is the upstream/main hash stored in agentic/.upgrade-state
  (gitignored, with the UTC time of the last successful --apply).

Options:
  (none)     Compare the stored hash with upstream/main and list file changes
  --check    Exit 0 when the stored hash is upstream/main, 1 otherwise
  --apply    Fetch, checkout framework paths when the hash differs, reinstall
  -h, --help Show this help

Requires a git remote named "upstream" pointing at the Beacon repository.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --apply) MODE="apply"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_upstream_remote() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not a git repository (expected under $ROOT)" >&2
    exit 1
  fi
  if ! git remote get-url upstream >/dev/null 2>&1; then
    cat <<'EOF' >&2
No 'upstream' remote found. Add the Beacon repository:

  git remote add upstream <beacon-repo-url>
EOF
    exit 1
  fi
}

fetch_upstream() {
  if ! git fetch upstream main; then
    echo "error: failed to fetch upstream main (network or remote configuration)." >&2
    exit 1
  fi
  if ! git rev-parse --verify upstream/main >/dev/null 2>&1; then
    echo "error: upstream/main not found after fetch." >&2
    exit 1
  fi
}

ensure_state_ignored() {
  local line='agentic/.upgrade-state'
  if [[ -f .gitignore ]] && grep -qxF "$line" .gitignore; then
    return 0
  fi
  if [[ -f .gitignore && -s .gitignore && -n "$(tail -c 1 .gitignore)" ]]; then
    printf '\n' >> .gitignore
  fi
  printf '# Last upstream/main hash applied by scripts/upgrade.sh. Local to this checkout.\n%s\n' "$line" >> .gitignore
  echo "Added ${line} to .gitignore"
}

read_upgrade_state() {
  APPLIED_COMMIT=""
  APPLIED_DATE=""
  [[ -f "$STATE_FILE" ]] || return 0
  APPLIED_COMMIT="$(sed -n 's/^commit=//p' "$STATE_FILE" | head -1)"
  APPLIED_DATE="$(sed -n 's/^date=//p' "$STATE_FILE" | head -1)"
}

write_upgrade_state() {
  local sha="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf 'commit=%s\ndate=%s\n' "$sha" "$now" > "$STATE_FILE"
}

upstream_has_path() {
  git cat-file -e "upstream/main:$1" 2>/dev/null
}

# Content diff of framework paths between two commits. Not a history walk.
framework_content_diff() {
  local from="$1"
  local listed=0 p diff_out
  for p in "${FRAMEWORK_PATHS[@]}"; do
    git cat-file -e "${from}:${p}" 2>/dev/null || continue
    upstream_has_path "$p" || continue
    diff_out="$(git diff --name-status "$from" upstream/main -- "$p" 2>/dev/null || true)"
    if [[ -n "$diff_out" ]]; then
      printf '%s\n' "$diff_out"
      listed=1
    fi
  done
  [[ "$listed" -eq 1 ]]
}

print_version_status() {
  local upstream_sha="$1"
  echo "Applied:  ${APPLIED_COMMIT:-none}  ${APPLIED_DATE:-}"
  echo "Upstream: ${upstream_sha}"
  if [[ -n "$APPLIED_COMMIT" && "$APPLIED_COMMIT" == "$upstream_sha" ]]; then
    echo "Up to date"
    return 0
  fi
  echo "Framework source differs from upstream/main."
  echo ""
  echo "File content that checkout would update:"
  local from=""
  if [[ -n "$APPLIED_COMMIT" ]] && git cat-file -e "${APPLIED_COMMIT}^{commit}" >/dev/null 2>&1; then
    from="$APPLIED_COMMIT"
  elif git rev-parse --verify HEAD >/dev/null 2>&1; then
    from="HEAD"
    echo "(no applied hash in this clone; comparing the current HEAD tree)"
  fi
  if [[ -n "$from" ]]; then
    framework_content_diff "$from" || echo "(no framework file differences)"
  fi
  return 1
}

# Copy one framework path from upstream/main into the worktree and the index,
# including deletions. Does not commit.
sync_framework_path() {
  local p="$1"
  if ! upstream_has_path "$p"; then
    echo "    skip $p (not on upstream/main)"
    return 0
  fi
  local removed
  removed="$(git diff --name-only --diff-filter=D HEAD upstream/main -- "$p" 2>/dev/null || true)"
  if [[ -n "$removed" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      git rm -q --ignore-unmatch -- "$f"
    done <<<"$removed"
  fi
  git checkout upstream/main -- "$p"
}

run_apply() {
  fetch_upstream
  ensure_state_ignored
  read_upgrade_state
  local upstream_sha
  upstream_sha="$(git rev-parse upstream/main)"

  local dirty untracked
  dirty="$(git diff --name-only -- "${FRAMEWORK_PATHS[@]}" 2>/dev/null || true)"
  untracked="$(git ls-files --others --exclude-standard -- "${FRAMEWORK_PATHS[@]}" 2>/dev/null | grep -vx 'agentic/.upgrade-state' || true)"
  if [[ -n "$dirty" || -n "$untracked" ]]; then
    echo "error: framework paths have uncommitted changes. Upgrade will not overwrite them." >&2
    echo "Commit or set them aside, then re-run. Other dirty files are ignored." >&2
    [[ -n "$dirty" ]] && printf '%s\n' "$dirty" >&2
    [[ -n "$untracked" ]] && printf '%s\n' "$untracked" >&2
    exit 1
  fi

  local backup_name=""
  if [[ "$APPLIED_COMMIT" == "$upstream_sha" ]]; then
    echo "Applied hash already matches upstream/main (${upstream_sha})."
    echo "Skipping checkout."
  else
    backup_name="backup/pre-upgrade-$(date +%Y%m%d)"
    if git show-ref --verify --quiet "refs/heads/${backup_name}"; then
      backup_name="backup/pre-upgrade-$(date +%Y%m%d-%H%M%S)"
    fi
    git branch "$backup_name"
    echo "Backup branch: ${backup_name}"
    echo "Updating framework source from ${upstream_sha}:"
    local p
    for p in "${FRAMEWORK_PATHS[@]}"; do
      echo "  - $p"
      sync_framework_path "$p"
    done
  fi

  # Refresh only IDE copies that already exist. `setup-agentic.sh all` also
  # writes the Antigravity plugin under ~/.gemini even when that app is absent.
  local -a targets=()
  if [[ -f "$ROOT/.cursor/.agentic-managed" || -f "$ROOT/.cursor/hooks.json" ]]; then
    targets+=(cursor)
  fi
  if [[ -d "$HOME/.claude/plugins/marketplaces/beacon-sdd-local" ]] \
    || { [[ -f "$HOME/.claude/plugins/installed_plugins.json" ]] \
      && grep -q 'beacon-sdd@beacon-sdd-local' "$HOME/.claude/plugins/installed_plugins.json"; }; then
    targets+=(claude)
  fi
  if [[ -d "$HOME/.gemini/config/plugins/beacon-sdd" ]]; then
    targets+=(antigravity)
  fi

  echo ""
  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No IDE install found. Framework source is updated."
    echo "Install once with: scripts/setup-agentic.sh cursor"
  else
    echo "Reinstalling: ${targets[*]} (project skills outside beacon/ are not touched)."
    local target
    for target in "${targets[@]}"; do
      if ! ./scripts/setup-agentic.sh "$target"; then
        echo "error: setup-agentic.sh ${target} failed. Applied hash was not updated." >&2
        [[ -n "$backup_name" ]] && echo "Backup branch: ${backup_name}" >&2
        exit 1
      fi
    done
  fi

  if [[ "$APPLIED_COMMIT" != "$upstream_sha" ]]; then
    write_upgrade_state "$upstream_sha"
    echo "Recorded ${upstream_sha} in agentic/.upgrade-state"
  fi

  echo ""
  echo "Upgrade complete. No commit was created."
  [[ -n "$backup_name" ]] && echo "Backup branch: ${backup_name}"
  local stat
  stat="$(git diff --cached --stat -- "${FRAMEWORK_PATHS[@]}" 2>/dev/null || true)"
  if [[ -n "$stat" ]]; then
    echo ""
    echo "Framework paths staged from upstream/main:"
    printf '%s\n' "$stat"
  fi
}

require_upstream_remote

if [[ "$MODE" == "apply" ]]; then
  run_apply
  exit 0
fi

fetch_upstream
read_upgrade_state
upstream_sha="$(git rev-parse upstream/main)"

if [[ "$MODE" == "check" ]]; then
  if print_version_status "$upstream_sha"; then
    exit 0
  fi
  exit 1
fi

print_version_status "$upstream_sha" || true
exit 0
