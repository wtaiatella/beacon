#!/usr/bin/env bash
# Keep .vscode/settings.json git.scanRepositories in sync with child repos
# (immediate subdirs of the workspace root that contain a .git/ folder).
#
# Used by:
#   - scripts/tools/clone-repo.sh  (after /clone)
#   - agentic/hooks/session-init.sh (on Cursor sessionStart / Claude SessionStart)
#
# Local-only: .vscode/ is gitignored by the workspace root "*" pattern.
# Idempotent. Fail-open friendly (callers may ignore non-zero exits).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETTINGS="$ROOT/.vscode/settings.json"

repos=()
for d in "$ROOT"/*/; do
  [ -e "$d/.git" ] || continue
  repos+=("$(basename "$d")")
done

IFS=$'\n' repos_sorted=($(printf '%s\n' "${repos[@]:-}" | LC_ALL=C sort -u))
unset IFS

mkdir -p "$ROOT/.vscode"

export SYNC_SETTINGS_PATH="$SETTINGS"
export SYNC_REPOS_LIST
SYNC_REPOS_LIST="$(printf '%s\n' "${repos_sorted[@]:-}")"

python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["SYNC_SETTINGS_PATH"])
repos = [r for r in os.environ.get("SYNC_REPOS_LIST", "").splitlines() if r.strip()]

defaults = {
    "git.autoRepositoryDetection": True,
    "git.repositoryScanMaxDepth": 2,
    "git.scanRepositories": [],
    "scm.repositories.visible": 10,
}

data = {}
if path.is_file():
    try:
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw) if raw.strip() else {}
        if not isinstance(data, dict):
            data = {}
    except json.JSONDecodeError:
        data = {}

for key, value in defaults.items():
    data.setdefault(key, value)

existing = data.get("git.scanRepositories", [])
if not isinstance(existing, list):
    existing = []

child_names = set(repos)
kept_custom = []
for entry in existing:
    if not isinstance(entry, str):
        continue
    name = entry.rstrip("/")
    # Preserve absolute/custom paths; refresh plain child folder names from disk.
    if "/" in name or name.startswith("."):
        kept_custom.append(entry)
        continue
    if name in child_names:
        continue
    # Stale relative name for a removed clone — drop it.

merged = sorted(repos) + kept_custom
seen = set()
ordered = []
for item in merged:
    if item in seen:
        continue
    seen.add(item)
    ordered.append(item)

changed = existing != ordered
data["git.scanRepositories"] = ordered
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(
    f"sync-vscode-git-repos: {'updated' if changed else 'unchanged'} "
    f"{path} ({len(ordered)} repo(s))"
)
for r in ordered:
    print(f"  - {r}")
PY
