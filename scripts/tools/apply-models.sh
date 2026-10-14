#!/usr/bin/env bash
# Apply model assignments to agent frontmatter.
#   Bulk: reads .cursor/models.yml OR .cursor/models.user.yml (see use_manual_models).
#   Single: apply-models.sh <agent> <model-id>  (e.g. plan gpt-5.2)
#   Snapshot/restore for per-session pipelines (see --snapshot / --restore).
#   Tests may set APPLY_MODELS_ROOT to a fixture directory (must mirror .cursor layout).
# Changes take effect immediately in Cursor — no restart needed.
set -euo pipefail

ROOT="${APPLY_MODELS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
USER_YML="$ROOT/.cursor/models.user.yml"
TEAM_YML="$ROOT/.cursor/models.yml"
CATALOG="$ROOT/docs/model-catalog.md"
AGENTS_DIR="$ROOT/.cursor/agents"
SNAPSHOT="${APPLY_MODELS_SNAPSHOT:-$ROOT/docs/local/.model-snapshot}"

DRY_RUN=0
FORCE=0
CONFIG=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0")                          Apply all mappings (team or manual — see below)
  $(basename "$0") <agent> <model-id>       Set one agent (blocked in manual mode unless --force)
  $(basename "$0") --show-source            Print whether bulk apply uses manual or team file
  $(basename "$0") --snapshot [path]        Save current model: values for all agents
  $(basename "$0") --restore [path]         Restore all agents from a snapshot file
  $(basename "$0") --restore-agent <agent> [path]  Restore one agent from snapshot
  $(basename "$0") --dry-run ...            Preview changes without writing files
  $(basename "$0") ... --force             With single-agent apply, override even in manual mode

Bulk source: reads .cursor/models.user.yml for use_manual_models (fail-closed to false).
  If true  → bulk mappings from .cursor/models.user.yml only (manual model mode).
  If false → bulk mappings from .cursor/models.yml (team baseline + dynamic pipeline).

Environment:
  APPLY_MODELS_SNAPSHOT   Override default snapshot path (default: docs/local/.model-snapshot)
  APPLY_MODELS_ROOT       For tests: workspace root containing .cursor/ (optional)

Valid model-id values: default, inherit, or any programmatic ID in docs/model-catalog.md.
EOF
}

warn_unknown_model() {
  local m="$1"
  if is_valid_model "$m"; then
    return 0
  fi
  echo "warning: model ID '$m' not found in docs/model-catalog.md — proceeding anyway" >&2
}

is_valid_model() {
  local m="$1"
  case "$m" in
    default|inherit) return 0 ;;
  esac
  [[ -f "$CATALOG" ]] || return 1
  grep -Fq "| \`$m\` |" "$CATALOG"
}

# Fail-closed: missing file, malformed flag, or anything other than true → false
parse_use_manual_models() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo false
    return 0
  fi
  local line val
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*use_manual_models: ]]; then
      val="${line#*:}"
      val="${val%%#*}"
      val=$(echo "$val" | tr -d '[:space:]')
      case "$val" in
        true|True|TRUE) echo true; return 0 ;;
        false|False|FALSE) echo false; return 0 ;;
        *) echo false; return 0 ;;
      esac
    fi
  done < "$f"
  echo false
}

use_manual_models_true() {
  [[ "$(parse_use_manual_models "$USER_YML")" == "true" ]]
}

resolve_bulk_config() {
  if use_manual_models_true; then
    CONFIG="$USER_YML"
  else
    CONFIG="$TEAM_YML"
  fi
}

show_bulk_source() {
  resolve_bulk_config
  if [[ "$CONFIG" == "$USER_YML" ]]; then
    echo "Bulk apply would use: manual ($USER_YML)"
  else
    echo "Bulk apply would use: team ($TEAM_YML)"
  fi
}

get_frontmatter_model() {
  local f="$1"
  awk '/^---$/{f++} f==1 && /^model:/{gsub(/^model:[[:space:]]*/,""); print; exit}' "$f"
}

set_frontmatter_model() {
  local agent_file="$1"
  local new="$2"
  local tmp
  tmp=$(mktemp)
  awk -v new="$new" '
    /^---$/ { fence++; print; next }
    fence == 1 && /^model:/ { print "model: " new; next }
    { print }
  ' "$agent_file" > "$tmp"
  mv "$tmp" "$agent_file"
}

apply_one_agent() {
  local agent="$1"
  local model="$2"
  local agent_file="$AGENTS_DIR/${agent}.md"

  warn_unknown_model "$model"

  if [[ ! -f "$agent_file" ]]; then
    echo "error: no agent file at $agent_file" >&2
    return 1
  fi

  local current
  current=$(get_frontmatter_model "$agent_file")

  if [[ "$current" == "$model" ]]; then
    echo "  OK  $agent — already $model"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  DRY $agent — $current → $model (not written)"
    return 0
  fi

  set_frontmatter_model "$agent_file" "$model"
  echo "  SET $agent — $current → $model"
}

bulk_from_yml() {
  local updated=0 skipped=0
  while IFS=: read -r agent model; do
    [[ "$agent" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${agent// }" ]] && continue

    agent=$(echo "$agent" | tr -d '[:space:]')
    model=$(echo "$model" | tr -d '[:space:]')
    [[ -z "$agent" || -z "$model" ]] && continue
    [[ "$agent" == "use_manual_models" ]] && continue

    local agent_file="$AGENTS_DIR/${agent}.md"
    if [[ ! -f "$agent_file" ]]; then
      echo "SKIP  $agent — no file at $agent_file"
      skipped=$((skipped + 1))
      continue
    fi

    warn_unknown_model "$model"

    local current
    current=$(get_frontmatter_model "$agent_file")

    if [[ "$current" == "$model" ]]; then
      echo "  OK  $agent — already $model"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  DRY $agent — $current → $model (not written)"
      updated=$((updated + 1))
      continue
    fi

    set_frontmatter_model "$agent_file" "$model"
    echo "  SET $agent — $current → $model"
    updated=$((updated + 1))
  done < "$CONFIG"

  echo ""
  echo "Done. $updated updated, $skipped skipped."
  if [[ "$updated" -gt 0 && "$DRY_RUN" -eq 0 ]]; then
    echo "Changes take effect immediately in Cursor."
  fi
}

cmd_snapshot() {
  local out="${1:-$SNAPSHOT}"
  mkdir -p "$(dirname "$out")"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  {
    echo "# apply-models snapshot"
    echo "# created $ts"
    echo "# restore with: $(basename "$0") --restore ${out/#$ROOT\//}"
    for f in "$AGENTS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      local base agent model
      base=$(basename "$f" .md)
      agent="$base"
      model=$(get_frontmatter_model "$f")
      printf '%s=%s\n' "$agent" "$model"
    done | sort
  } > "$out"
  echo "Snapshot written: $out"
}

cmd_restore() {
  local snap="${1:-$SNAPSHOT}"
  if [[ ! -f "$snap" ]]; then
    echo "error: snapshot not found: $snap" >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "${line// }" ]] && continue
    local agent="${line%%=*}"
    local model="${line#*=}"
    agent=$(echo "$agent" | tr -d '[:space:]')
    model=$(echo "$model" | tr -d '[:space:]')
    [[ -z "$agent" ]] && continue
    apply_one_agent "$agent" "$model"
  done < "$snap"
  echo "Restore complete."
}

cmd_restore_agent() {
  local agent="$1"
  local snap="${2:-$SNAPSHOT}"
  if [[ ! -f "$snap" ]]; then
    echo "error: snapshot not found: $snap" >&2
    exit 1
  fi
  local line model
  line=$(grep -E "^${agent}=" "$snap" | tail -1) || true
  if [[ -z "$line" ]]; then
    echo "error: agent '$agent' not in snapshot $snap" >&2
    exit 1
  fi
  model="${line#*=}"
  model=$(echo "$model" | tr -d '[:space:]')
  apply_one_agent "$agent" "$model"
}

# --- argument parsing ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --show-source)
      show_bulk_source
      exit 0
      ;;
    --snapshot)
      shift
      cmd_snapshot "${1:-}"
      exit 0
      ;;
    --restore)
      shift
      cmd_restore "${1:-}"
      exit 0
      ;;
    --restore-agent)
      shift
      if [[ $# -lt 1 ]]; then
        echo "error: --restore-agent requires <agent> [snapshot-path]" >&2
        exit 1
      fi
      a="$1"
      shift
      cmd_restore_agent "$a" "${1:-}"
      exit 0
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#ARGS[@]} -eq 0 ]]; then
  resolve_bulk_config
  if [[ ! -f "$CONFIG" ]]; then
    echo "error: bulk config not found: $CONFIG" >&2
    exit 1
  fi
  bulk_from_yml
  exit 0
fi

# Allow --dry-run and --force after positional args: apply-models.sh plan gpt-5.2 --dry-run --force
EXTRA=()
for a in "${ARGS[@]}"; do
  if [[ "$a" == "--dry-run" ]]; then
    DRY_RUN=1
  elif [[ "$a" == "--force" ]]; then
    FORCE=1
  else
    EXTRA+=("$a")
  fi
done
ARGS=("${EXTRA[@]}")

if [[ ${#ARGS[@]} -ne 2 ]]; then
  echo "error: expected <agent> <model-id> or use --help" >&2
  exit 1
fi

if use_manual_models_true && [[ "$FORCE" -ne 1 ]]; then
  echo "error: manual mode is on (use_manual_models: true in .cursor/models.user.yml)." >&2
  echo "Edit that file and run bulk apply, or pass --force to override one agent anyway." >&2
  exit 1
fi

apply_one_agent "${ARGS[0]}" "${ARGS[1]}"
