#!/usr/bin/env bash
# Upgrade the agentic workspace from upstream. Fetches changes, reports diffs,
# and optionally merges with backup branch + conflict guidance. Requires a git
# remote named "upstream". Run setup.sh after merge to validate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="default"

usage() {
  cat <<'EOF'
Usage: upgrade.sh [option]

  Help upgrade the agentic workspace from the upstream remote.

Options:
  (none)     Check upstream, report status, and summarize files that would change
  --check    Exit 0 if up to date with upstream/main, 1 if updates are available
  --apply    Fetch upstream, merge, run setup on success; see messages if conflicts
  -h, --help Show this help

Requires a git remote named "upstream" pointing at the original repository.
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
No 'upstream' remote found. Add the original repository:

  git remote add upstream <original-repo-url>
EOF
    exit 1
  fi
}

summarize_upstream_changes() {
  local mb
  mb="$(git merge-base HEAD upstream/main 2>/dev/null || true)"
  if [[ -z "$mb" ]]; then
    echo "Could not compute merge-base with upstream/main (fetch may have failed)." >&2
    return 1
  fi
  echo ""
  echo "Files changed on upstream since merge-base (would merge in):"
  git diff --name-status "${mb}..upstream/main" 2>/dev/null || true
}

run_apply() {
  local stashed=0 backup_name merge_ok=0
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    git stash push -m "workspace-pre-upgrade-$(date +%Y%m%d%H%M%S)"
    stashed=1
  fi

  git fetch upstream

  backup_name="backup/pre-upgrade-$(date +%Y%m%d)"
  if git show-ref --verify --quiet "refs/heads/${backup_name}"; then
    backup_name="backup/pre-upgrade-$(date +%Y%m%d-%H%M%S)"
  fi
  git branch "$backup_name"

  if git merge upstream/main --no-edit; then
    merge_ok=1
  else
    echo ""
    echo "Merge conflicts in the following files:"
    git diff --name-only --diff-filter=U
    echo ""
    local hotspots=0
    while IFS= read -r f; do
      case "$f" in
        .cursor/rules/*|.cursor/agents/*|.cursor/hooks.json)
          if [[ "$hotspots" -eq 0 ]]; then
            echo "Likely conflict hotspots (review carefully):"
            hotspots=1
          fi
          echo "  - $f"
          ;;
      esac
    done < <(git diff --name-only --diff-filter=U)
    echo ""
    echo "Resolve conflicts keeping your customizations where needed. Common patterns:"
    echo "  - Agents you customized should usually keep your version."
    echo "  - New upstream agents and rules should generally be accepted."
    echo "After resolving: git add -A && git commit && (optional) git stash pop"
    [[ "$stashed" -eq 1 ]] && echo "Your pre-upgrade changes are still in the stash."
    exit 1
  fi

  if [[ "$merge_ok" -eq 1 ]]; then
    if ./scripts/setup.sh; then
      echo ""
      echo "Upgrade complete. Backup branch: ${backup_name}"
    else
      echo "error: setup.sh failed after merge; inspect the tree and backup branch ${backup_name}" >&2
      [[ "$stashed" -eq 1 ]] && git stash pop || true
      exit 1
    fi
  fi

  if [[ "$stashed" -eq 1 ]]; then
    git stash pop || echo "warning: stash pop had conflicts; resolve manually." >&2
  fi

  echo "Done."
}

require_upstream_remote

if [[ "$MODE" == "apply" ]]; then
  run_apply
  exit 0
fi

if ! git fetch upstream main 2>/dev/null; then
  echo "error: failed to fetch upstream main (network or remote configuration)." >&2
  exit 1
fi

if ! git rev-parse --verify upstream/main >/dev/null 2>&1; then
  echo "error: upstream/main not found after fetch." >&2
  exit 1
fi

count="$(git rev-list HEAD..upstream/main --count 2>/dev/null || echo 0)"

if [[ "$MODE" == "check" ]]; then
  if [[ "$count" -eq 0 ]]; then
    echo "Up to date"
    exit 0
  fi
  echo "${count} commits behind upstream"
  exit 1
fi

LOCAL_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "untagged")
UPSTREAM_TAG=$(git describe --tags --abbrev=0 upstream/main 2>/dev/null || echo "untagged")
echo "Local version:    $LOCAL_TAG"
echo "Upstream version: $UPSTREAM_TAG"

if [[ "$count" -eq 0 ]]; then
  echo "Up to date"
else
  echo "${count} commits behind upstream"
  summarize_upstream_changes || true
fi

exit 0
