#!/usr/bin/env bash
# List ticket folders under docs/specs/*/ with ticket key, a one-line
# description, and pipeline status from _state.json.
# Used by the session-init hook and /scrum for spec discovery.
# Loose docs/specs/*.md files are ignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPECS="$ROOT/docs/specs"

usage() {
  echo "Usage: $(basename "$0")"
  echo "  Lists ticket folders under docs/specs/*/ (not loose *.md files)."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

shopt -s nullglob
dirs=("$SPECS"/*/)
if [[ ${#dirs[@]} -eq 0 ]]; then
  echo "No ticket folders in docs/specs/."
  exit 0
fi

md_cell() {
  local s=$1
  s=${s//$'\n'/ }
  s=${s//$'\r'/ }
  s=${s//|/\\| }
  s=$(printf '%s' "$s" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
  if [[ ${#s} -gt 120 ]]; then
    s="${s:0:119}…"
  fi
  printf '%s' "$s"
}

echo "| Pasta | Ticket | Descrição | Status |"
echo "|---|---|---|---|"

for d in "${dirs[@]}"; do
  [[ -d "$d" ]] || continue
  rel="${d#"$ROOT"/}"
  rel="${rel%/}"
  name="$(basename "$d")"

  ticket=""
  slug=""
  status=""
  has_state=0
  if [[ -f "$d/_state.json" ]]; then
    has_state=1
    parsed=$(node -e '
const fs = require("fs");
let s;
try {
  s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
} catch (e) {
  process.stdout.write("\t\tunreadable _state.json");
  process.exit(0);
}
if (!s || typeof s !== "object" || Array.isArray(s)) {
  process.stdout.write("\t\tunreadable _state.json");
  process.exit(0);
}
const ticket = s.ticket || s.ticket_key || "";
const slug = s.slug || "";
const step = s.current_step || "";
let val = "";
if (step && s.steps && typeof s.steps === "object" && !Array.isArray(s.steps) && s.steps[step] != null) {
  val = typeof s.steps[step] === "string" ? s.steps[step] : String(s.steps[step]);
}
let status = "";
if (step && val) status = step + ": " + val;
else if (step) status = step;
process.stdout.write([ticket, slug, status].join("\t"));
' "$d/_state.json" 2>/dev/null || printf '\t\tunreadable _state.json')
    ticket="${parsed%%$'\t'*}"
    rest="${parsed#*$'\t'}"
    slug="${rest%%$'\t'*}"
    status="${rest#*$'\t'}"
  else
    status="legacy (no _state.json)"
  fi

  desc=""
  if [[ -f "$d/ticket.md" ]]; then
    desc=$(grep -m1 -E '^#+[[:space:]]+' "$d/ticket.md" 2>/dev/null | sed -E 's/^#+[[:space:]]+//' || true)
  fi
  if [[ -z "$desc" && -n "$slug" ]]; then
    desc="$slug"
  fi
  if [[ -z "$desc" ]]; then
    desc="$name"
  fi
  if [[ "$has_state" -eq 1 && -z "$status" ]]; then
    status="-"
  fi

  printf '| %s | %s | %s | %s |\n' \
    "$(md_cell "$rel")" \
    "$(md_cell "$ticket")" \
    "$(md_cell "$desc")" \
    "$(md_cell "$status")"
done
