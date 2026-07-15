#!/usr/bin/env bash
#
# generate-changelog.sh — Markdown changelog for GitLab Release descriptions
#
# Behavior
# --------
# - End of range: --ref / GENERATE_CHANGELOG_REF (default: HEAD). This is the
#   exclusive upper bound of the displayed history (typically the commit being
#   released or CI_COMMIT_SHA).
# - Start of range (exclusive lower bound), in order of precedence:
#   1) --since / GENERATE_CHANGELOG_SINCE — explicit git ref (commit, tag, branch).
#   2) Otherwise: latest tag reachable from the end ref:
#        git describe --tags --abbrev=0 <end_ref>
#      Commit range is always:  <start>..<end>  (git log range syntax).
# - "No previous tag" (no --since, and git describe finds no tag): the script
#   exits with status 2 and prints a short message to stderr. There is no
#   implicit full-history or first-release template — pass an explicit base,
#   e.g.  --since "$(git rev-list --max-parents=0 HEAD)"  for a first release.
# - Output format: Markdown with a title line and grouped sections (### Added,
#   ### Fixed, ### Documentation, …) derived from conventional commit prefixes
#   (feat:, fix:, …). Unprefixed commits go under ### Other. Merge commits are
#   omitted (--no-merges).
# - Destination: stdout, or a file if -o / --output or GENERATE_CHANGELOG_OUTPUT
#   is set (CLI overrides environment).
# - Non-interactive / CI: use env vars and/or flags; the script never prompts.
# - Any failing git command causes a non-zero exit (typically 1); missing tag
#   when required uses exit 2 as documented above.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

END_REF="${GENERATE_CHANGELOG_REF:-HEAD}"
SINCE_REF="${GENERATE_CHANGELOG_SINCE:-}"
OUTPUT_PATH=""

usage() {
  cat <<'EOF'
Usage: generate-changelog.sh [options]

  Emit Markdown suitable for a GitLab Release description from git commits
  in the range <start>..<end>. Default start: latest reachable tag from <end>;
  default end: HEAD.

Options:
  --ref <ref>             End ref (default: HEAD or GENERATE_CHANGELOG_REF)
  --since <ref>           Start ref, exclusive (overrides tag discovery), or
                          set GENERATE_CHANGELOG_SINCE
  -o, --output <path>     Write to file (default: stdout, or GENERATE_CHANGELOG_OUTPUT)
  -h, --help              Show this help

Environment (non-interactive / CI):
  GENERATE_CHANGELOG_REF     Same as --ref
  GENERATE_CHANGELOG_SINCE   Same as --since
  GENERATE_CHANGELOG_OUTPUT  Same as --output

Exit status:
  0 success
  1 usage, invalid ref, or other git error
  2 no reachable tag and --since / GENERATE_CHANGELOG_SINCE not set
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)
      END_REF="${2:-}"
      if [[ -z "$END_REF" ]]; then echo "error: --ref requires a value" >&2; exit 1; fi
      shift 2
      ;;
    --since)
      SINCE_REF="${2:-}"
      if [[ -z "$SINCE_REF" ]]; then echo "error: --since requires a value" >&2; exit 1; fi
      shift 2
      ;;
    -o|--output)
      OUTPUT_PATH="${2:-}"
      if [[ -z "$OUTPUT_PATH" ]]; then echo "error: --output requires a path" >&2; exit 1; fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "${GENERATE_CHANGELOG_OUTPUT:-}" && -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$GENERATE_CHANGELOG_OUTPUT"
fi

if [[ ! -d .git ]]; then
  echo "error: not a git repository (expected .git under $ROOT)" >&2
  exit 1
fi

git rev-parse --verify "$END_REF" >/dev/null

if [[ -n "$SINCE_REF" ]]; then
  git rev-parse --verify "$SINCE_REF" >/dev/null
  RANGE_START="$SINCE_REF"
  RANGE_LABEL="$SINCE_REF"
else
  if ! RANGE_START="$(git describe --tags --abbrev=0 "$END_REF" 2>/dev/null)"; then
    cat >&2 <<'EOF'
error: no reachable tag from the end ref (and no --since / GENERATE_CHANGELOG_SINCE).
For a first release, pass an explicit base, for example:
  --since "$(git rev-list --max-parents=0 HEAD)"
EOF
    exit 2
  fi
  RANGE_LABEL="$RANGE_START"
fi

RANGE="${RANGE_START}..${END_REF}"

categorize() {
  local subject=$1 head type
  case "$subject" in
    *:*)
      head="${subject%%:*}"
      type="${head%%(*}"
      case "$type" in
        feat) echo added ;;
        fix) echo fixed ;;
        docs) echo docs ;;
        refactor) echo changed ;;
        chore) echo maintenance ;;
        perf) echo performance ;;
        *) echo other ;;
      esac
      ;;
    *) echo other ;;
  esac
}

added=() fixed=() docs=() changed=() maintenance=() performance=() other=()

while IFS=$'\t' read -r hash subject; do
  [[ -z "${hash:-}" ]] && continue
  line="- ${subject} (\`${hash}\`)"
  case "$(categorize "$subject")" in
    added) added+=("$line") ;;
    fixed) fixed+=("$line") ;;
    docs) docs+=("$line") ;;
    changed) changed+=("$line") ;;
    maintenance) maintenance+=("$line") ;;
    performance) performance+=("$line") ;;
    other) other+=("$line") ;;
  esac
done < <(git log --no-merges --format=$'%h\t%s' "$RANGE")

emit_section() {
  local title="$1"
  shift
  (($# == 0)) && return 0
  echo "### ${title}"
  local line
  for line in "$@"; do echo "$line"; done
  echo ""
}

{
  # Empty arrays + "set -u" make "${name[@]}" expand fail in some bash versions;
  # relax only for emitting grouped sections.
  set +u
  echo "## Changes since \`${RANGE_LABEL}\`"
  echo ""
  echo "_Range: \`${RANGE}\`_"
  echo ""

  emit_section "Added" "${added[@]}"
  emit_section "Fixed" "${fixed[@]}"
  emit_section "Documentation" "${docs[@]}"
  emit_section "Changed" "${changed[@]}"
  emit_section "Maintenance" "${maintenance[@]}"
  emit_section "Performance" "${performance[@]}"
  emit_section "Other" "${other[@]}"

  total=$(( ${#added[@]} + ${#fixed[@]} + ${#docs[@]} + ${#changed[@]} + ${#maintenance[@]} + ${#performance[@]} + ${#other[@]} ))
  set -u
  if [[ "$total" -eq 0 ]]; then
    echo "_No commits in this range._"
    echo ""
  fi
} | if [[ -n "$OUTPUT_PATH" ]]; then
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  cat >"$OUTPUT_PATH"
else
  cat
fi
