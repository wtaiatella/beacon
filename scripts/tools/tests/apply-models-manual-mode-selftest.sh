#!/usr/bin/env bash
# Non-destructive checks for manual vs team bulk source selection.
# Uses APPLY_MODELS_ROOT fixtures (no writes to the real workspace).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/scripts/tools/apply-models.sh"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/apply-models-selftest.XXXXXX")"
cleanup() { rm -rf "$tmp_root"; }
trap cleanup EXIT

mkdir -p "$tmp_root/.cursor/agents"
echo '---
name: plan
model: default
---
' > "$tmp_root/.cursor/agents/plan.md"

# Team YAML only path (no user file → fail-closed false → team)
cat > "$tmp_root/.cursor/models.yml" <<'EOF'
plan: composer-2
EOF

out=$(APPLY_MODELS_ROOT="$tmp_root" "$SCRIPT" --show-source)
if ! echo "$out" | grep -Fq "team"; then
  echo "FAIL: expected team when models.user.yml missing, got: $out" >&2
  exit 1
fi

# Manual: user file with use_manual_models: true
cat > "$tmp_root/.cursor/models.user.yml" <<'EOF'
use_manual_models: true
plan: gpt-5.3-codex
EOF

out=$(APPLY_MODELS_ROOT="$tmp_root" "$SCRIPT" --show-source)
if ! echo "$out" | grep -Fq "manual"; then
  echo "FAIL: expected manual when use_manual_models true, got: $out" >&2
  exit 1
fi

# Malformed flag → fail-closed team
cat > "$tmp_root/.cursor/models.user.yml" <<'EOF'
use_manual_models: maybe
plan: gpt-5.3-codex
EOF

out=$(APPLY_MODELS_ROOT="$tmp_root" "$SCRIPT" --show-source)
if ! echo "$out" | grep -Fq "team"; then
  echo "FAIL: expected team when flag malformed, got: $out" >&2
  exit 1
fi

echo "apply-models manual-mode selftest: OK"
