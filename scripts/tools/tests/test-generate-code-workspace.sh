#!/usr/bin/env bash
# Golden JSON for generate_code_workspace.py (ROAD-48 Phase 1).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PY="$ROOT/scripts/tools/generate_code_workspace.py"
WRAPPER="$ROOT/scripts/tools/generate-code-workspace.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

orch="$tmp/orchestrator"
tgt="$tmp/projects/my-target"
mkdir -p "$orch" "$tgt"
orch_abs="$(cd "$orch" && pwd -P)"
tgt_abs="$(cd "$tgt" && pwd -P)"
out="$tmp/session.code-workspace"

python3 "$PY" "$orch_abs" "$tgt_abs" "$out" || fail "python generator exited non-zero"
python3 -m json.tool "$out" >/dev/null || fail "output is not valid JSON"

grep -q '"name": "Orchestrator"' "$out" || fail "missing Orchestrator folder"
grep -q '"name": "Target"' "$out" || fail "missing Target folder"
grep -q "git.scanRepositories" "$out" || fail "missing git.scanRepositories"

python3 <<PY || fail "structure mismatch"
import json, sys
from pathlib import Path
p = Path("$out")
d = json.loads(p.read_text(encoding="utf-8"))
assert d["folders"][0]["path"] == "$orch_abs"
assert d["folders"][1]["path"] == "$tgt_abs"
assert d["settings"]["git.scanRepositories"] == ["$tgt_abs"]
PY

# Wrapper delegates to the same Python module.
out2="$tmp/w2.code-workspace"
"$WRAPPER" "$orch_abs" "$tgt_abs" "$out2" || fail "wrapper failed"
cmp -s "$out" "$out2" || fail "wrapper output differs from direct python"

echo "OK generate-code-workspace / generate_code_workspace.py"
