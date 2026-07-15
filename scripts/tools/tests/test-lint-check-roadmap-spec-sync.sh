#!/usr/bin/env bash
# Self-test: verify-roadmap-spec-sync.sh + lint-check.sh Status-Sync (ROAD-45 Phase 2).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VERIFY="$ROOT/scripts/tools/verify-roadmap-spec-sync.sh"
LINT="$ROOT/scripts/tools/lint-check.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- verify only: pass (archived Completed) ---
mkdir -p "$TMP/pass/docs/specs" "$TMP/pass/docs/roadmaps/completed"
cat >"$TMP/pass/docs/specs/2026-01-01-road-77-sync-ok-spec.md" <<'EOF'
---
status: completed
---
EOF
cat >"$TMP/pass/docs/roadmaps/completed/ROAD-77-sync-ok.md" <<'EOF'
### ROAD-77

**Status:** Completed (2026-01-01)
EOF

echo "── verify-roadmap-spec-sync: expect pass (archived) ──"
"$VERIFY" --root "$TMP/pass" || fail "expected exit 0 when roadmap only in completed/"

# --- verify only: fail (Planned in active root) ---
mkdir -p "$TMP/bad1/docs/specs" "$TMP/bad1/docs/roadmaps"
cat >"$TMP/bad1/docs/specs/2026-01-01-road-88-drift-spec.md" <<'EOF'
---
status: completed
---
EOF
cat >"$TMP/bad1/docs/roadmaps/ROAD-88-drift.md" <<'EOF'
### ROAD-88

**Status:** Planned
EOF

echo "── verify-roadmap-spec-sync: expect fail (Planned) ──"
set +e
"$VERIFY" --root "$TMP/bad1" 2>/dev/null
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "expected non-zero when active roadmap is Planned"

# --- verify only: fail (Completed label but still in active root) ---
mkdir -p "$TMP/bad2/docs/specs" "$TMP/bad2/docs/roadmaps"
cat >"$TMP/bad2/docs/specs/2026-01-01-road-99-stuck-spec.md" <<'EOF'
---
status: completed
---
EOF
cat >"$TMP/bad2/docs/roadmaps/ROAD-99-stuck.md" <<'EOF'
### ROAD-99

**Status:** Completed
EOF

echo "── verify-roadmap-spec-sync: expect fail (Completed but not archived) ──"
set +e
"$VERIFY" --root "$TMP/bad2" 2>/dev/null
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "expected non-zero when Status Completed but file still under active root"

# --- lint-check end-to-end on pass fixture ---
echo "── lint-check.sh: pass fixture ──"
"$LINT" "$TMP/pass" || fail "lint-check should pass on synced roadmap/spec tree"

# --- lint-check fails when verify would fail ---
echo "── lint-check.sh: expect failure on drift fixture ──"
set +e
"$LINT" "$TMP/bad1" 2>/dev/null
st=$?
set -e
[[ "$st" -ne 0 ]] || fail "lint-check should fail when verify fails"

echo "OK roadmap/spec sync self-test"
