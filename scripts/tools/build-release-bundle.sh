#!/usr/bin/env bash
#
# build-release-bundle.sh — tarball distribution for GitLab Release assets
#
# Staged content (paths relative to repository root)
# ----------------------------------------------------
# - README.md
# - .cursor/          (rules, agents, skills, hooks config — no .git)
#       mcp.json, models.user.yml excluded: OAuth/tokens and local MCP endpoints
#       often live in mcp.json; manual model overrides are personal — not for bundles
# - scripts/hooks/
# - scripts/tools/    excluding:
#       scripts/tools/tests/          (fixture + integration tests)
#       **/__pycache__/               (Python bytecode dirs)
#       *.pyc
# - docs/             excluding internal-only / local artifacts:
#       docs/sessions/* except docs/sessions/README.md
#       docs/audit.log, docs/usage-events.tsv (if present)
#
# Not included (by design — not part of this bundle contract)
# -----------------------------------------------------------
# - .git, **/.git
# - knowledge/, scripts/ (except hooks/ and tools/ as above), .gitlab-ci.yml, …
# - Secret-oriented names anywhere under staged trees:
#       .env, .env.*, *.pem, *.p12, id_rsa*, id_ed25519*, *.key (private-key style)
#
# Output
# ------
# - ${BUILD_RELEASE_BUNDLE_OUTPUT_DIR:-dist}/agentic-workspace-${VERSION}.tar.gz
# - Archive contains a single top-level directory: agentic-workspace-${VERSION}/
#
# Version resolution (first match wins)
# -------------------------------------
# 1. --version <string> or first positional argument
# 2. VERSION environment variable
# 3. CI_COMMIT_TAG (e.g. GitLab CI) if set
#
# Requires: bash, rsync, tar, gzip; run from any cwd (uses script location for repo root).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-}"
# --output-dir / BUILD_RELEASE_BUNDLE_OUTPUT_DIR: maintainer-controlled (trusted input).
OUTPUT_DIR="${BUILD_RELEASE_BUNDLE_OUTPUT_DIR:-dist}"

usage() {
  cat <<'EOF'
Usage: build-release-bundle.sh --version <VERSION>
       build-release-bundle.sh <VERSION>

  Build agentic-workspace-${VERSION}.tar.gz for Release asset upload.

Options:
  --version <VERSION>   Release / package version string (required if not set elsewhere)
  -o, --output-dir <DIR>
                        Directory for the tarball (default: dist, or BUILD_RELEASE_BUNDLE_OUTPUT_DIR)
  -h, --help            Show this help

Environment:
  VERSION                        Same as --version
  BUILD_RELEASE_BUNDLE_OUTPUT_DIR  Output directory (default: dist)
  CI_COMMIT_TAG                  Used as VERSION when VERSION is unset (CI)

Exit status: 0 success, 1 usage or validation error, 2 missing prerequisite command
EOF
}

if ! command -v rsync >/dev/null 2>&1; then
  echo "error: rsync is required but not found in PATH" >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then echo "error: --version requires a value" >&2; exit 1; fi
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="${2:-}"
      if [[ -z "$OUTPUT_DIR" ]]; then echo "error: --output-dir requires a value" >&2; exit 1; fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "${VERSION:-}" ]]; then
        echo "error: unexpected extra argument: $1" >&2
        exit 1
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  VERSION="${CI_COMMIT_TAG:-}"
fi

if [[ -z "$VERSION" ]]; then
  echo "error: VERSION is required (use --version, positional arg, or CI_COMMIT_TAG)" >&2
  exit 1
fi

if [[ "$VERSION" == *'/'* || "$VERSION" == *'..'* ]]; then
  echo "error: VERSION must not contain '/' or '..'" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[A-Za-z0-9._+-]+$ ]]; then
  echo "error: VERSION must match only safe tag characters: ^[A-Za-z0-9._+-]+$ (no whitespace or control characters)" >&2
  exit 1
fi

BUNDLE_TOP="agentic-workspace-${VERSION}"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/build-release-bundle.XXXXXX")"
DEST="${STAGING}/${BUNDLE_TOP}"

cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

mkdir -p "$DEST/scripts/hooks" "$DEST/scripts/tools" "$DEST/docs" "$DEST/.cursor"

# --- README
cp "$ROOT/README.md" "$DEST/README.md"

# --- .cursor (no git metadata in normal tree; exclude junk + secret-like files)
rsync -a \
  --exclude '.git/' \
  --exclude 'mcp.json' \
  --exclude 'models.user.yml' \
  --exclude '.DS_Store' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '*.pem' \
  --exclude '*.p12' \
  --exclude 'id_rsa*' \
  --exclude 'id_ed25519*' \
  --exclude '*.key' \
  "$ROOT/.cursor/" "$DEST/.cursor/"

# --- scripts/hooks
rsync -a \
  --exclude '.git/' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '*.pem' \
  --exclude '*.p12' \
  --exclude 'id_rsa*' \
  --exclude 'id_ed25519*' \
  --exclude '*.key' \
  "$ROOT/scripts/hooks/" "$DEST/scripts/hooks/"

# --- scripts/tools (exclude test tree and bytecode)
rsync -a \
  --exclude '.git/' \
  --exclude 'tests/' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '*.pem' \
  --exclude '*.p12' \
  --exclude 'id_rsa*' \
  --exclude 'id_ed25519*' \
  --exclude '*.key' \
  "$ROOT/scripts/tools/" "$DEST/scripts/tools/"

# --- docs (keep sessions README only; drop ephemeral session files and local logs)
if [[ -d "$ROOT/docs" ]]; then
  rsync -a \
    --exclude '.git/' \
    --include 'sessions/' \
    --include 'sessions/README.md' \
    --exclude 'sessions/*' \
    --exclude 'audit.log' \
    --exclude 'usage-events.tsv' \
    --exclude '.env' \
    --exclude '.env.*' \
    --exclude '*.pem' \
    --exclude '*.p12' \
    --exclude 'id_rsa*' \
    --exclude 'id_ed25519*' \
    --exclude '*.key' \
    "$ROOT/docs/" "$DEST/docs/"
fi

if [[ "$OUTPUT_DIR" == /* ]]; then
  OUT_DIR="$OUTPUT_DIR"
else
  OUT_DIR="$ROOT/$OUTPUT_DIR"
fi
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/${BUNDLE_TOP}.tar.gz"

tar -czf "$OUT_FILE" -C "$STAGING" "$BUNDLE_TOP"

echo "$OUT_FILE"
