#!/usr/bin/env bash
# Self-test: archive-roadmap.sh --dry-run and apply in a throwaway git repo.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ARCHIVE="$ROOT/scripts/tools/archive-roadmap.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
git init -q
git config user.email "archive-test@example.com"
git config user.name "archive-test"

mkdir -p docs/roadmaps/completed

cat > docs/roadmaps/ROAD-99-archive-fixture.md <<'EOF'
### ROAD-99: Archive fixture

**Status:** Planned

#### Deliverables

- [ ] x
EOF

git add -A
git commit -q -m "init"

echo "── archive-roadmap: dry-run ──"
out=$("$ARCHIVE" --root "$TMP" --dry-run ROAD-99 2>&1) || fail "dry-run exit non-zero"
echo "$out" | grep -q "\[dry-run\].*git.*mv" || fail "dry-run should show git mv"
echo "$out" | grep -q "ROAD-99-archive-fixture" || fail "dry-run should mention roadmap file"

[[ -f "$TMP/docs/roadmaps/ROAD-99-archive-fixture.md" ]] || fail "dry-run must not move file"
git -C "$TMP" diff --cached --quiet || fail "dry-run must not stage"

echo "── archive-roadmap: apply ──"
"$ARCHIVE" --root "$TMP" 99 || fail "archive apply failed"
[[ -f "$TMP/docs/roadmaps/completed/ROAD-99-archive-fixture.md" ]] || fail "expected file under completed/"
[[ ! -f "$TMP/docs/roadmaps/ROAD-99-archive-fixture.md" ]] || fail "active copy should be gone"
git -C "$TMP" diff --cached --name-only | grep -q "docs/roadmaps/completed/ROAD-99-archive-fixture.md" || fail "expected staged path in completed/"

echo "── archive-roadmap: idempotent (already archived) ──"
out2=$("$ARCHIVE" --root "$TMP" ROAD-99 2>&1) || fail "second run should exit 0"
echo "$out2" | grep -qi "already archived" || fail "second run should report already archived"

echo "── archive-roadmap: duplicate active+completed rejected ──"
git -C "$TMP" reset -q HEAD -- .
git -C "$TMP" checkout -q .
echo "### ROAD-99: Dup" > docs/roadmaps/ROAD-99-second-active.md
git -C "$TMP" add docs/roadmaps/ROAD-99-second-active.md
git -C "$TMP" commit -q -m "add second active"
if "$ARCHIVE" --root "$TMP" 99 2>/dev/null; then
  fail "expected non-zero when multiple active ROAD-99 files"
fi

echo "OK archive-roadmap self-test"
