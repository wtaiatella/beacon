#!/usr/bin/env bash
# Self-test: sync-roadmap-status.sh dry-run and apply in a throwaway git repo (fixture tree).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SYNC="$ROOT/scripts/tools/sync-roadmap-status.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
git init -q
git config user.email "sync-test@example.com"
git config user.name "sync-test"

mkdir -p docs/specs docs/roadmaps/completed

# Completed spec without -road-n- segment → warn, no crash
cat > docs/specs/2026-01-01-plain-spec.md <<'EOF'
---
status: completed
---
EOF

# ROAD-99: active roadmap should sync
cat > docs/specs/2026-01-01-road-99-sync-test-spec.md <<'EOF'
---
status: completed
---
EOF

cat > docs/roadmaps/ROAD-99-sync-test-fixture.md <<'EOF'
### ROAD-99: Sync fixture

**Status:** Planned

#### Deliverables

- [ ] x
EOF

git add -A
git commit -q -m "init"

echo "── sync-roadmap-status: dry-run ──"
out=$("$SYNC" --root "$TMP" --dry-run 2>&1) || fail "dry-run exit non-zero"
echo "$out" | grep -q "dry-run.*ROAD-99" || fail "dry-run should mention ROAD-99"
echo "$out" | grep -q "git -C" || fail "dry-run should show git mv"

echo "── sync-roadmap-status: apply ──"
"$SYNC" --root "$TMP" || fail "sync apply failed"
[[ -f "$TMP/docs/roadmaps/completed/ROAD-99-sync-test-fixture.md" ]] || fail "expected file in completed/"
[[ ! -f "$TMP/docs/roadmaps/ROAD-99-sync-test-fixture.md" ]] || fail "active copy should be gone"
grep -q '^\*\*Status:\*\* Completed$' "$TMP/docs/roadmaps/completed/ROAD-99-sync-test-fixture.md" || fail "Status should be Completed"

echo "── sync-roadmap-status: idempotent (already archived) ──"
out2=$("$SYNC" --root "$TMP" 2>&1) || true
echo "$out2" | grep -qi "already archived" || fail "second run should skip archived ROAD-99"

echo "OK sync-roadmap-status self-test"
