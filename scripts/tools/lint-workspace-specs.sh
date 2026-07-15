#!/usr/bin/env bash
#
# Content-level validation for architecture specs under docs/specs/.
# Normative rules: .cursor/skills/generate-spec/SKILL.md
#
# Requirements: Bash 3.2+ (macOS default). No Bash 4-only features (no mapfile,
# no associative arrays). CI typically uses Bash 4+ on Linux; behavior is identical.
#
# Exit codes:
#   0  All spec files passed (or nothing to validate under docs/specs/).
#   1  One or more validation failures.
#
# Usage: lint-workspace-specs.sh [--help|-h]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SPECS_DIR="$ROOT/docs/specs"
FAIL=0

usage() {
  echo "Usage: $(basename "$0")"
  echo "  Validates docs/specs/*-spec.md files (filename, frontmatter, section order, task tags)."
  echo "  Exits 0 if there are no *-spec.md files (nothing to validate)."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

shopt -s nullglob
SPEC_FILES=("$SPECS_DIR"/*-spec.md)

if [[ ${#SPEC_FILES[@]} -eq 0 ]]; then
  echo "── Spec Content Lint ──"
  echo "OK No spec files under docs/specs/ (nothing to validate)"
  exit 0
fi

echo "── Spec Content Lint ──"

# Filename patterns (generate-spec): default YYYY-MM-DD-{kebab-slug}-spec.md; optional
# YYYY-MM-DDTHHMMSSZ-{kebab}-spec.md or YYYY-MM-DD-HHMM-{kebab}-spec.md (kebab: lowercase segments).
_spec_name_default='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*-spec\.md$'
_spec_name_t_affix='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]+Z-[a-z0-9]+(-[a-z0-9]+)*-spec\.md$'
_spec_name_hhmm_affix='^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*-spec\.md$'

for f in "${SPEC_FILES[@]}"; do
  base=$(basename "$f")
  echo "Checking $base"

  if ! [[ "$base" =~ $_spec_name_default || "$base" =~ $_spec_name_t_affix || "$base" =~ $_spec_name_hhmm_affix ]]; then
    echo "FAIL $base -- filename must match YYYY-MM-DD-{kebab-slug}-spec.md or optional timestamp affix (see generate-spec)"
    FAIL=1
    continue
  fi

  FM=$(awk 'BEGIN{c=0} /^---$/{c++; next} c==1{print}' "$f")
  if [[ -z "${FM// }" ]]; then
    echo "FAIL $base -- missing or empty YAML frontmatter"
    FAIL=1
    continue
  fi

  echo "$FM" | grep -qE '^status:[[:space:]]*(draft|in-progress|review|completed|archived)[[:space:]]*$' || {
    echo "FAIL $base -- frontmatter: status must be draft|in-progress|review|completed|archived"
    FAIL=1
  }
  echo "$FM" | grep -qE '^created:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$' || {
    echo "FAIL $base -- frontmatter: created must be YYYY-MM-DD"
    FAIL=1
  }
  echo "$FM" | grep -qE '^last-updated:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$' || {
    echo "FAIL $base -- frontmatter: last-updated must be YYYY-MM-DD"
    FAIL=1
  }

  if ! grep -qE '^#[[:space:]]+[^[:space:]]' "$f"; then
    echo "FAIL $base -- missing H1 title after frontmatter"
    FAIL=1
  fi

  # Collect ## headers (top-level sections only); Bash 3.2–safe (no mapfile)
  HEADERS=()
  while IFS= read -r _h; do
    HEADERS+=("$_h")
  done < <(grep -nE '^##[[:space:]]+[^#]' "$f" | sed 's/^[0-9]*:##[[:space:]]*//' | sed 's/[[:space:]]*$//')

  # Order matches generate-spec (API Contracts optional only between Dependencies and Task List)
  REQUIRED=(
    "Overview"
    "Scope"
    "Goals / Non-Goals"
    "Architecture"
    "Dependencies"
    "Task List"
    "Testing Strategy"
    "Acceptance Criteria"
    "Risks & Mitigations"
    "Open Questions"
  )

  ri=0
  for h in "${HEADERS[@]}"; do
    if [[ "$h" == "API Contracts" ]]; then
      # Optional section: only valid immediately before Task List (ri == 5 after matching through Dependencies; next required is Task List)
      if [[ "$ri" -ne 5 ]]; then
        echo "FAIL $base -- unexpected section 'API Contracts' (allowed only before Task List, after Dependencies)"
        FAIL=1
        break
      fi
      continue
    fi
    if [[ $ri -lt ${#REQUIRED[@]} && "$h" == "${REQUIRED[$ri]}" ]]; then
      ((ri++)) || true
    elif [[ $ri -lt ${#REQUIRED[@]} ]]; then
      echo "FAIL $base -- unexpected section header: '$h' (expected next: '${REQUIRED[$ri]}')"
      FAIL=1
      break
    fi
  done
  if [[ $ri -ne ${#REQUIRED[@]} && $FAIL -eq 0 ]]; then
    echo "FAIL $base -- missing or out-of-order sections (need generate-spec order; API Contracts optional before Task List only)"
    FAIL=1
  fi

  # Task tags inside ## Task List ... ## Testing Strategy (flexible ## whitespace)
  TASK_BLOCK=$(awk '
    $0 ~ /^##[[:space:]]+Task[[:space:]]+List[[:space:]]*$/ { show=1; next }
    $0 ~ /^##[[:space:]]+Testing[[:space:]]+Strategy[[:space:]]*$/ { show=0 }
    show { print }
  ' "$f")

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line// }" ]] && continue
    [[ "$line" =~ ^###[[:space:]] ]] && continue
    [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]x]\] ]] || continue
    if ! [[ "$line" =~ ^[[:space:]]*-[[:space:]]\[[[:space:]x]\][[:space:]]\[(dev|sre|data)(:[a-zA-Z0-9_.-]+)?\][[:space:]] ]]; then
      echo "FAIL $base -- invalid task tag (expected [dev|sre|data] or [domain:repo]): $line"
      FAIL=1
    fi
  done <<< "$TASK_BLOCK"

  echo "OK $base"
done

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
echo "OK All specs passed content lint"
