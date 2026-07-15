#!/usr/bin/env bash
# Wrapper for generate_code_workspace.py — valid UTF-8 JSON for multi-root attach (ROAD-48).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/generate_code_workspace.py"

usage() {
  cat <<'EOF'
Usage: generate-code-workspace.sh <orchestrator-root> <target-root> <output.code-workspace>

  Writes JSON with folders "Orchestrator" + "Target" and settings.git.scanRepositories
  listing the target root (absolute paths via Python pathlib resolve).

Order (for attach-project.sh): resolve orchestrator and target with pwd -P, then pass
those absolute paths here so JSON matches the on-disk canonical paths.

See also: scripts/tools/attach-project.sh --help
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 3 ]]; then
  usage
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && exit 0
  exit 1
fi

exec python3 "$PY" "$1" "$2" "$3"
