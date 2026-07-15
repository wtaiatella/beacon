#!/usr/bin/env bash
# Emit a suggested GitLab MR title and markdown body from an architecture spec.
# Reads markdown only; prints to stdout (paste into GitLab UI or glab mr create --description).
# Does not call git or GitLab APIs.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mr-description-from-spec.sh <path-to-spec.md>

Prints a suggested MR title (first line) and a markdown body including:
  - Tasks (from ## Task List)
  - Acceptance criteria (from ## Acceptance Criteria)
  - Spec file path (relative if under cwd, else absolute)

Options:
  -h, --help    Show this help

Environment:
  SUMMARY_PATH  Optional path to a pipeline summary markdown; if set and readable,
                a "## Summary" section is included after the spec link line.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

SPEC="$1"
if [[ ! -f "$SPEC" ]]; then
  echo "mr-description-from-spec: not a file: $SPEC" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" 2>/dev/null || true

# Prefer path relative to workspace root when spec is inside it
SPEC_ABS="$(cd "$(dirname "$SPEC")" && pwd)/$(basename "$SPEC")"
SPEC_DISPLAY="$SPEC"
case "$SPEC_ABS" in
  "$ROOT"/*) SPEC_DISPLAY="${SPEC_ABS#$ROOT/}" ;;
  *) SPEC_DISPLAY="$SPEC_ABS" ;;
esac

strip_frontmatter() {
  awk '
    BEGIN { state = 0 }
    /^---[[:space:]]*$/ {
      if (state == 0) { state = 1; next }
      if (state == 1) { state = 2; next }
    }
    state == 1 { next }
    { print }
  ' "$1"
}

# First H1 line as title (strip leading # and spaces)
read -r MR_TITLE < <(strip_frontmatter "$SPEC" | awk '/^#[^#]/ { sub(/^#[[:space:]]+/, ""); print; exit }')
if [[ -z "${MR_TITLE:-}" ]]; then
  MR_TITLE="$(basename "$SPEC" .md)"
fi

extract_section() {
  # $1 = file, $2 = section heading without ##
  awk -v want="$2" '
    BEGIN { insec = 0 }
    $0 ~ "^##[[:space:]]+" want "[[:space:]]*$" { insec = 1; next }
    insec && /^##[[:space:]]/ { exit }
    insec { print }
  ' "$1"
}

BODY_SRC="$(strip_frontmatter "$SPEC")"
TMP="$(mktemp)"
printf '%s\n' "$BODY_SRC" >"$TMP"
TASK_BLOCK="$(extract_section "$TMP" "Task List")"
AC_BLOCK="$(extract_section "$TMP" "Acceptance Criteria")"
rm -f "$TMP"

# Domain tags → labels hint (from [dev], [sre], [data] in task lines)
LABELS=""
if grep -qE '\[(dev|sre|data)(:[^]]+)?\]' "$SPEC" 2>/dev/null; then
  for tag in dev sre data; do
    if grep -qE "\\[${tag}(:[^]]+)?\\]" "$SPEC"; then
      LABELS="${LABELS}${LABELS:+, }${tag}"
    fi
  done
fi

echo "$MR_TITLE"
echo ""
echo "---"
echo ""
echo "## Spec"
echo ""
echo "- Path: \`$SPEC_DISPLAY\`"
if [[ -n "${SUMMARY_PATH:-}" && -f "${SUMMARY_PATH}" ]]; then
  SUM_DISP="$SUMMARY_PATH"
  case "$(cd "$(dirname "$SUMMARY_PATH")" && pwd)/$(basename "$SUMMARY_PATH")" in
    "$ROOT"/*) SUM_DISP="${SUM_DISP#./}" ;;
  esac
  echo "- Summary artifact: \`$SUM_DISP\` (concatenate key bullets below the MR body if pasting manually)"
fi
echo ""
echo "## Tasks"
echo ""
if [[ -n "${TASK_BLOCK//[$'\t\r\n ']/}" ]]; then
  printf '%s\n' "$TASK_BLOCK"
else
  echo "_(No ## Task List section found; see spec file.)_"
fi
echo ""
echo "## Acceptance criteria"
echo ""
if [[ -n "${AC_BLOCK//[$'\t\r\n ']/}" ]]; then
  printf '%s\n' "$AC_BLOCK"
else
  echo "_(No ## Acceptance Criteria section found; see spec file.)_"
fi
echo ""
if [[ -n "$LABELS" ]]; then
  echo "## Suggested GitLab labels (from spec domain tags)"
  echo ""
  echo "Tags present in task lines map to labels: \`$LABELS\`"
  echo ""
  echo "_Example (you run locally; do not commit tokens):_ \`glab mr create --label dev --label sre\` (adjust to match your project labels)."
fi
if [[ -n "${SUMMARY_PATH:-}" && -f "${SUMMARY_PATH}" ]]; then
  echo ""
  echo "## Summary (excerpt)"
  echo ""
  head -n 40 "$SUMMARY_PATH" | sed 's/^/    /' || true
fi
