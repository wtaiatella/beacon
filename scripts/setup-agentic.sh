#!/usr/bin/env bash
# Install the canonical agentic/ framework into one or more IDE runtimes.
# Usage: scripts/setup-agentic.sh <claude|cursor|antigravity|all> [--dry-run] [--keep-claude]
#
# - Framework source of truth: agentic/{agents,skills,commands,hooks}
# - Only paths recorded in each runtime's .agentic-managed manifest are pruned
# - Project skills, agents, and commands are not copied or linked
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/agentic"
DRY_RUN=0
KEEP_CLAUDE=0
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --keep-claude) KEEP_CLAUDE=1 ;;
    -h|--help)
      TARGET="--help"
      ;;
    claude|cursor|antigravity|all)
      TARGET="$arg"
      ;;
    *)
      echo "error: unknown argument '$arg'" >&2
      TARGET="--help"
      ;;
  esac
done

usage() {
  cat <<'EOF'
Usage: scripts/setup-agentic.sh <claude|cursor|antigravity|all> [--dry-run] [--keep-claude]

  claude       Install the framework as a user-level Claude plugin
               (~/.claude/plugins/marketplaces/beacon-sdd-local, not ~/.claude/skills).
               If that plugin is already installed and the source is unchanged,
               only refresh workspace control files (CLAUDE.md, adapter docs)
               and drop the managed .claude/ framework mirror.
  cursor       Install + adapt entirely under .cursor/*/beacon/ (agents, hooks,
               rules, skills) plus .cursor/hooks.json. Also deactivates managed
               Claude and legacy .agents mirrors so / entries are not duplicated.
               Does not copy or link project skills, agents, or commands.
  antigravity  Install the framework as a global Google Antigravity plugin
               (~/.gemini/config/plugins/beacon-sdd) + workspace control files (AGENTS.md).
  all          Run claude + cursor + antigravity (no Claude deactivation)

  --dry-run      Print actions only
  --keep-claude  With `cursor`: leave .claude/ managed framework files in place
                 (dual-IDE; expect duplicate / unless you block third-party discovery)

Canonical source: agentic/

Prune policy: only removes paths previously listed in <runtime>/.agentic-managed
that are no longer produced by this install. Unmanaged files are left untouched.

Cursor adapter specifics:
  - Framework content installs under a `beacon/` subfolder inside each
    .cursor/ directory it uses — anything outside beacon/ is structurally
    not part of the SDD framework (no naming-prefix convention needed):
  - agents  → .cursor/agents/beacon/  (subagents / Task — slash/persona entrypoints)
  - skills  → .cursor/skills/beacon/  (path refs rewritten off .claude/; NO command→skill emission)
  - commands stay in the Claude plugin — Cursor does not mirror them as skills
    (avoids duplicate / entries alongside .cursor/agents/)
  - hooks   → .cursor/hooks/beacon/ + top-level .cursor/hooks.json
               (shared agentic/hooks/* + overlay agentic/adapters/cursor/hooks/*)
  - rules   → .cursor/rules/beacon/*.mdc  (always-on context; Cursor equivalent of CLAUDE.md)
  - docs    → docs/adapters/cursor/  (from agentic/adapters/cursor/docs/)
  - by default, prune .claude/ paths listed in .claude/.agentic-managed
  - by default, prune .agents/ paths listed in .agents/.agentic-managed
    (legacy framework copies only; other files there are left alone)
  - does not copy or symlink project skills, agents, or commands

Claude adapter:
  - framework → ~/.claude/plugins/marketplaces/beacon-sdd-local/beacon-sdd
    (skills, agents, commands, hooks). Slash names are /beacon-sdd:<name>.
  - skips the plugin copy when it is already installed and the source stamp matches
  - agentic/adapters/claude/CLAUDE.md → ./CLAUDE.md  (generated; edit the agentic source)
  - agentic/adapters/claude/docs/ → docs/adapters/claude/
  - does not copy the framework into .claude/; prunes previously managed copies
  - optional overlay agentic/adapters/claude/hooks/* is not installed into the project

Antigravity adapter:
  - framework → ~/.gemini/config/plugins/beacon-sdd
    (plugin.json, hooks.json, rules, skills, agents, hooks).
  - skills and personas available as Antigravity progressive disclosure skills.
  - agentic/AGENTS.md → ./AGENTS.md (canonical workspace contract).
  - agentic/adapters/antigravity/docs/ → docs/adapters/antigravity/.
  - prunes legacy .agent/ stub if previously managed.
EOF
}

if [[ -z "$TARGET" || "$TARGET" == "--help" ]]; then
  usage
  exit 2
fi

if [[ ! -d "$SRC/agents" || ! -d "$SRC/skills" || ! -d "$SRC/commands" || ! -d "$SRC/hooks" ]]; then
  echo "error: incomplete agentic/ tree under $SRC" >&2
  exit 1
fi

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: $*"
  else
    "$@"
  fi
}

# Globals filled during an install_* call, then flushed to the manifest.
MANIFEST_ROOT=""
MANAGED_TMP=""

managed_begin() {
  MANIFEST_ROOT="$1"
  MANAGED_TMP="$(mktemp)"
}

managed_add() {
  printf '%s\n' "$1" >> "$MANAGED_TMP"
}

# Remove every path listed in a runtime's .agentic-managed (framework only).
# Leaves every other file intact. Clears the manifest afterward.
deactivate_managed_runtime() {
  local runtime_root="$1"
  local label="$2"
  local manifest="$runtime_root/.agentic-managed"
  local rel removed=0

  if [[ ! -f "$manifest" ]]; then
    echo "    skip deactivate $label (no $manifest — run setup for that runtime once, or remove duplicates manually)"
    return 0
  fi

  echo "    deactivate $label mirror (prune managed paths under $runtime_root)"
  while IFS= read -r rel || [[ -n "${rel:-}" ]]; do
    [[ -z "$rel" || "$rel" == \#* ]] && continue
    if [[ -e "$runtime_root/$rel" || -L "$runtime_root/$rel" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY: prune $runtime_root/$rel (cursor exclusive)"
      else
        echo "prune: $runtime_root/$rel (cursor exclusive — avoid / duplicates)"
        rm -rf "$runtime_root/$rel"
      fi
      removed=$((removed + 1))
    fi
  done < "$manifest"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: would clear $manifest ($removed paths pruned)"
  else
    {
      echo "# Generated by scripts/setup-agentic.sh — do not edit by hand"
      echo "# Lists framework paths managed under this runtime root."
      echo "# Cleared by Cursor install (framework mirror deactivated)."
      echo "# Re-run: scripts/setup-agentic.sh claude"
    } > "$manifest"
    echo "    deactivated $label ($removed managed paths removed)"
  fi
}

managed_finish() {
  local manifest="$MANIFEST_ROOT/.agentic-managed"
  local old_tmp new_sorted
  new_sorted="$(mktemp)"
  sort -u "$MANAGED_TMP" > "$new_sorted"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: would write $manifest ($(wc -l < "$new_sorted" | tr -d ' ') paths)"
    if [[ -f "$manifest" ]]; then
      old_tmp="$(mktemp)"
      sort -u "$manifest" > "$old_tmp"
      while IFS= read -r rel || [[ -n "${rel:-}" ]]; do
        [[ -z "$rel" || "$rel" == \#* ]] && continue
        if ! grep -Fxq "$rel" "$new_sorted"; then
          echo "DRY: prune $MANIFEST_ROOT/$rel"
        fi
      done < "$old_tmp"
      rm -f "$old_tmp"
    fi
    rm -f "$MANAGED_TMP" "$new_sorted"
    MANAGED_TMP=""
    return 0
  fi

  if [[ -f "$manifest" ]]; then
    while IFS= read -r rel || [[ -n "${rel:-}" ]]; do
      [[ -z "$rel" || "$rel" == \#* ]] && continue
      if ! grep -Fxq "$rel" "$new_sorted"; then
        if [[ -e "$MANIFEST_ROOT/$rel" || -L "$MANIFEST_ROOT/$rel" ]]; then
          echo "prune: $MANIFEST_ROOT/$rel (was managed; no longer in agentic)"
          rm -rf "$MANIFEST_ROOT/$rel"
        fi
      fi
    done < "$manifest"
  fi

  mkdir -p "$MANIFEST_ROOT"
  {
    echo "# Generated by scripts/setup-agentic.sh — do not edit by hand"
    echo "# Lists framework paths managed under this runtime root."
    cat "$new_sorted"
  } > "$manifest"

  rm -f "$MANAGED_TMP" "$new_sorted"
  MANAGED_TMP=""
}

copy_file_managed() {
  local from="$1"
  local to="$2"
  local rel="$3"
  run mkdir -p "$(dirname "$to")"
  run cp "$from" "$to"
  managed_add "$rel"
}

sync_dir_managed() {
  local src_dir="$1"
  local dest_dir="$2"
  local rel_prefix="$3"

  run mkdir -p "$dest_dir"

  local path name
  for path in "$src_dir"/*; do
    [[ -e "$path" ]] || continue
    name="$(basename "$path")"
    if [[ -d "$path" ]]; then
      run rm -rf "$dest_dir/$name"
      run cp -R "$path" "$dest_dir/$name"
    else
      run cp "$path" "$dest_dir/$name"
    fi
    managed_add "${rel_prefix}/${name}"
  done
}

# Overlay IDE-specific hooks onto the shared hooks dir without pruning siblings.
# Skips README* so documentation in adapters/<ide>/hooks/ is not installed as hooks.
overlay_adapter_hooks() {
  local ide="$1"
  local dest_dir="$2"
  local rel_prefix="${3:-hooks}"
  local src_dir="$SRC/adapters/$ide/hooks"

  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  run mkdir -p "$dest_dir"

  local path name
  local count=0
  for path in "$src_dir"/*; do
    [[ -e "$path" ]] || continue
    name="$(basename "$path")"
    case "$name" in
      README|README.md|README.txt) continue ;;
    esac
    if [[ -d "$path" ]]; then
      run rm -rf "$dest_dir/$name"
      run cp -R "$path" "$dest_dir/$name"
    else
      run cp "$path" "$dest_dir/$name"
    fi
    managed_add "${rel_prefix}/${name}"
    count=$((count + 1))
  done
  if [[ "$count" -gt 0 ]]; then
    echo "    overlay adapters/$ide/hooks → $dest_dir ($count file(s))"
  fi
}

# Rewrite Claude-oriented paths to Cursor-native locations in a tree.
# Framework content lives under a `beacon/` subfolder inside each .cursor/
# directory (agents/skills/rules/hooks) so anything outside beacon/ is
# structurally not part of the SDD framework — no naming-prefix convention
# needed. This rewrite runs only on those beacon/ trees.
adapt_cursor_paths() {
  local dest="$1"
  [[ -d "$dest" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: adapt_cursor_paths $dest"
    return 0
  fi

  local skill_names=()
  local s
  for s in "$SRC/skills"/*; do
    [[ -e "$s" ]] || continue
    skill_names+=("$(basename "$s")")
  done

  while IFS= read -r -d '' f; do
    case "$f" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf) continue ;;
    esac
    local tmp
    tmp="$(mktemp)"
    # Base rewrites (framework agents/hooks move under .cursor/.../beacon/ for
    # Cursor; commands are never mirrored into Cursor)
    sed \
      -e 's|\.claude/agents/|.cursor/agents/beacon/|g' \
      -e 's|\.claude/commands/|.cursor/commands/|g' \
      -e 's|\.claude/hooks/|.cursor/hooks/beacon/|g' \
      "$f" > "$tmp"

    # Framework skills: .claude/skills/<name>/ → .cursor/skills/beacon/<name>/
    local name
    for name in "${skill_names[@]}"; do
      sed -i '' -e "s|\\.claude/skills/${name}/|.cursor/skills/beacon/${name}/|g" "$tmp"
    done
    mv "$tmp" "$f"
  done < <(find "$dest" -type f -print0 2>/dev/null)
}

# Install adapter-owned docs into docs/adapters/<name>/ (gitignored generated tree).
install_adapter_docs() {
  local name="$1"
  local src_docs="$SRC/adapters/$name/docs"
  local dest="$ROOT/docs/adapters/$name"

  if [[ ! -d "$src_docs" ]]; then
    echo "    skip docs/adapters/$name (no $src_docs)"
    return 0
  fi

  echo "    docs → docs/adapters/$name/"
  managed_begin "$dest"
  # Flat files under docs/ (not nested skill dirs)
  local path base
  run mkdir -p "$dest"
  for path in "$src_docs"/*; do
    [[ -e "$path" ]] || continue
    base="$(basename "$path")"
    if [[ -d "$path" ]]; then
      run rm -rf "$dest/$base"
      run cp -R "$path" "$dest/$base"
    else
      run cp "$path" "$dest/$base"
    fi
    managed_add "$base"
  done
  managed_finish
}

# User-level Claude plugin. Not under ~/.claude/skills: on this machine that
# path is a symlink to ~/.agents/skills, which Cursor loads as its own skills root.
CLAUDE_PLUGIN_NAME="beacon-sdd"
CLAUDE_MARKET_NAME="beacon-sdd-local"

claude_plugin_market_root() {
  printf '%s\n' "$HOME/.claude/plugins/marketplaces/$CLAUDE_MARKET_NAME"
}

claude_plugin_source_stamp() {
  {
    tar -cf - \
      -C "$SRC" agents skills commands hooks \
      -C "$SRC/adapters/claude" settings.json
    # Fold in the optional per-install model override (Claude-specific file)
    # so editing it alone (without touching agentic/ itself) still
    # invalidates the cached stamp.
    if [[ -f "$SRC/models/claude.yml" ]]; then
      cat "$SRC/models/claude.yml"
    fi
  } | shasum -a 256 | awk '{print $1}'
}

claude_plugin_installed() {
  local installed_json="$HOME/.claude/plugins/installed_plugins.json"
  [[ -f "$installed_json" ]] || return 1
  grep -q "\"${CLAUDE_PLUGIN_NAME}@${CLAUDE_MARKET_NAME}\"" "$installed_json"
}

install_claude_plugin() {
  local market plugin stamp dest_stamp
  market="$(claude_plugin_market_root)"
  plugin="$market/$CLAUDE_PLUGIN_NAME"
  stamp="$(claude_plugin_source_stamp)"
  dest_stamp="$plugin/.sdd-source-stamp"

  if claude_plugin_installed && [[ -f "$dest_stamp" && "$(cat "$dest_stamp")" == "$stamp" ]]; then
    echo "    plugin ${CLAUDE_PLUGIN_NAME}@${CLAUDE_MARKET_NAME} already installed (source unchanged)"
    return 0
  fi

  echo "    sync Claude plugin → $plugin"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: would write plugin tree, marketplace manifest, and claude plugin install"
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    echo "error: claude CLI not found; cannot register the user plugin" >&2
    exit 1
  fi

  mkdir -p "$plugin/.claude-plugin" "$plugin/hooks" "$market/.claude-plugin"
  rm -rf "$plugin/agents" "$plugin/skills" "$plugin/commands" "$plugin/hooks"
  cp -R "$SRC/agents" "$plugin/agents"
  cp -R "$SRC/skills" "$plugin/skills"
  cp -R "$SRC/commands" "$plugin/commands"
  cp -R "$SRC/hooks" "$plugin/hooks"
  apply_model_overrides "$plugin/agents" "claude"
  chmod +x "$plugin/hooks/"*.sh 2>/dev/null || true
  sed 's|$CLAUDE_PROJECT_DIR/.claude/hooks/|${CLAUDE_PLUGIN_ROOT}/hooks/|g' \
    "$SRC/adapters/claude/settings.json" > "$plugin/hooks/hooks.json"
  cat > "$plugin/.claude-plugin/plugin.json" <<EOF
{
  "name": "$CLAUDE_PLUGIN_NAME",
  "description": "Agentic SDD framework (skills, agents, commands, hooks)",
  "version": "0.0.0"
}
EOF
  printf '%s\n' "$stamp" > "$dest_stamp"
  cat > "$market/.claude-plugin/marketplace.json" <<EOF
{
  "name": "$CLAUDE_MARKET_NAME",
  "owner": { "name": "beacon" },
  "plugins": [
    {
      "name": "$CLAUDE_PLUGIN_NAME",
      "source": "./$CLAUDE_PLUGIN_NAME",
      "description": "Agentic SDD framework"
    }
  ]
}
EOF

  local known="$HOME/.claude/plugins/known_marketplaces.json"
  if [[ ! -f "$known" ]] || ! grep -q "\"$CLAUDE_MARKET_NAME\"" "$known"; then
    claude plugin marketplace add "$market" --scope user
  fi

  if claude_plugin_installed; then
    claude plugin uninstall "${CLAUDE_PLUGIN_NAME}@${CLAUDE_MARKET_NAME}" --scope user -y
  fi
  claude plugin install "${CLAUDE_PLUGIN_NAME}@${CLAUDE_MARKET_NAME}" --scope user -y
  echo "    installed ${CLAUDE_PLUGIN_NAME}@${CLAUDE_MARKET_NAME} (slash prefix /${CLAUDE_PLUGIN_NAME}:)"
}

# Per-install, per-adapter model override (optional, gitignored). Every
# agent's canonical frontmatter is `model: inherit` — this is the only place
# a different tier is applied, and only for agents listed in the matching
# agentic/models/<target>.yml (one file per adapter — see
# agentic/models/example.yml for the format). No-op if that file is absent
# (the common case — inherit everywhere).
apply_model_overrides() {
  local agents_dir="$1"
  local target="$2"
  local overrides="$SRC/models/$target.yml"
  [[ -f "$overrides" ]] || return 0
  [[ -d "$agents_dir" ]] || return 0

  local line key value file
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ -z "${line//[[:space:]]/}" ]] && continue
    key="$(echo "${line%%:*}" | xargs)"
    value="$(echo "${line#*:}" | xargs)"
    [[ -z "$key" || -z "$value" ]] && continue
    file="$agents_dir/$key.md"
    if [[ ! -f "$file" ]]; then
      echo "    warning: models/$target.yml overrides unknown agent '$key' (no $file)" >&2
      continue
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY: model override $key -> $value ($file)"
    else
      sed -i '' "s/^model: .*/model: $value/" "$file"
    fi
  done < "$overrides"
}

# Shared, IDE-agnostic SDD contract. Cursor reads it natively; Claude Code's
# CLAUDE.md imports it via `@AGENTS.md`. Installed regardless of which
# adapter target is chosen.
install_agents_md() {
  local agents_md_src="$SRC/AGENTS.md"
  if [[ ! -f "$agents_md_src" ]]; then
    echo "error: missing $agents_md_src" >&2
    exit 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: cp $agents_md_src → $ROOT/AGENTS.md"
  else
    cp "$agents_md_src" "$ROOT/AGENTS.md"
    echo "    wrote AGENTS.md (from agentic/AGENTS.md)"
  fi
}

install_claude() {
  echo "==> Installing Claude adapter → user plugin + workspace control files"

  install_agents_md

  local claude_md_src="$SRC/adapters/claude/CLAUDE.md"
  if [[ ! -f "$claude_md_src" ]]; then
    echo "error: missing $claude_md_src" >&2
    exit 1
  fi

  install_claude_plugin

  # Drop the project framework mirror. Same-named files under .claude/ override
  # the plugin, and skills there show up as a second /. Only paths previously
  # listed in .claude/.agentic-managed are removed.
  managed_begin "$ROOT/.claude"
  managed_finish

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: cp $claude_md_src → $ROOT/CLAUDE.md"
  else
    cp "$claude_md_src" "$ROOT/CLAUDE.md"
    echo "    wrote CLAUDE.md (from agentic/adapters/claude/CLAUDE.md)"
  fi

  install_adapter_docs "claude"
  echo "    done (plugin is user-level)"
}

install_cursor() {
  echo "==> Installing Cursor adapter → .cursor/ (agents, hooks, rules, skills)"

  install_agents_md

  local rules_src="$SRC/adapters/cursor/rules"
  if [[ ! -d "$rules_src" ]]; then
    echo "error: missing $rules_src (Cursor always-on rules)" >&2
    exit 1
  fi

  # --- .cursor: agents + hooks + rules + skills, all under a `beacon/`
  # subfolder so anything outside beacon/ is structurally not part of the
  # SDD framework. hooks.json itself must stay at the top-level path Cursor
  # requires (.cursor/hooks.json) and points into .cursor/hooks/beacon/.
  # Project skills, agents, and commands are not copied or linked.
  managed_begin "$ROOT/.cursor"
  sync_dir_managed "$SRC/agents" "$ROOT/.cursor/agents/beacon" "agents/beacon"
  sync_dir_managed "$SRC/hooks" "$ROOT/.cursor/hooks/beacon" "hooks/beacon"
  overlay_adapter_hooks "cursor" "$ROOT/.cursor/hooks/beacon" "hooks/beacon"
  sync_dir_managed "$rules_src" "$ROOT/.cursor/rules/beacon" "rules/beacon"
  sync_dir_managed "$SRC/skills" "$ROOT/.cursor/skills/beacon" "skills/beacon"
  apply_model_overrides "$ROOT/.cursor/agents/beacon" "cursor"
  adapt_cursor_paths "$ROOT/.cursor/agents/beacon"
  adapt_cursor_paths "$ROOT/.cursor/hooks/beacon"
  adapt_cursor_paths "$ROOT/.cursor/skills/beacon"
  # rules are authored for Cursor paths already — no .claude rewrite needed
  if [[ "$DRY_RUN" -eq 0 ]]; then
    chmod +x "$ROOT/.cursor/hooks/beacon/"*.sh 2>/dev/null || true
  fi
  copy_file_managed "$SRC/adapters/cursor/hooks.json" "$ROOT/.cursor/hooks.json" "hooks.json"
  managed_finish

  # Previous installs wrote framework skills here. Remove only those managed
  # paths. Anything else under .agents/ belongs to the project.
  if [[ -f "$ROOT/.agents/.agentic-managed" ]]; then
    deactivate_managed_runtime "$ROOT/.agents" "legacy .agents skills"
  fi

  install_adapter_docs "cursor"

  # Action audit is Cursor-adapter-only now. Drop any legacy shared copy under
  # .claude/ so a stale PostToolUse entry cannot call a removed strategy.
  if [[ -f "$ROOT/.claude/hooks/tool-audit.sh" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY: rm $ROOT/.claude/hooks/tool-audit.sh (legacy shared audit)"
    else
      rm -f "$ROOT/.claude/hooks/tool-audit.sh"
      echo "    removed legacy .claude/hooks/tool-audit.sh"
    fi
  fi
  if [[ "$KEEP_CLAUDE" -eq 1 && -f "$SRC/adapters/claude/settings.json" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY: refresh .claude/settings.json (no tool-audit)"
    else
      cp "$SRC/adapters/claude/settings.json" "$ROOT/.claude/settings.json"
      echo "    refreshed .claude/settings.json (audit not wired for Claude yet)"
    fi
  fi

  # Cursor also discovers .claude/{agents,skills,commands}. Deactivate the
  # managed Claude mirror so / is not duplicated — unless dual-IDE requested.
  if [[ "$KEEP_CLAUDE" -eq 1 ]]; then
    echo "    keep .claude/ (--keep-claude); watch for duplicate / entries"
  else
    deactivate_managed_runtime "$ROOT/.claude" "Claude (.claude)"
  fi

  echo "    done (agents+hooks+rules+skills→.cursor/*/beacon/; legacy .agents skills removed)"
}

ANTIGRAVITY_PLUGIN_NAME="beacon-sdd"

antigravity_plugin_root() {
  printf '%s\n' "$HOME/.gemini/config/plugins/$ANTIGRAVITY_PLUGIN_NAME"
}

antigravity_plugin_source_stamp() {
  {
    tar -cf - \
      -C "$SRC" agents skills commands hooks \
      -C "$SRC/adapters/antigravity" plugin.json hooks.json rules
  } | shasum -a 256 | awk '{print $1}'
}

adapt_antigravity_paths() {
  local dest="$1"
  [[ -d "$dest" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: adapt_antigravity_paths $dest"
    return 0
  fi

  local skill_names=()
  local s
  for s in "$dest/skills"/*; do
    [[ -e "$s" ]] || continue
    skill_names+=("$(basename "$s")")
  done

  while IFS= read -r -d '' f; do
    case "$f" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf) continue ;;
    esac
    local tmp
    tmp="$(mktemp)"
    sed \
      -e 's|\.claude/agents/|~/.gemini/config/plugins/beacon-sdd/agents/|g' \
      -e 's|\.claude/commands/|~/.gemini/config/plugins/beacon-sdd/skills/|g' \
      -e 's|\.claude/hooks/|~/.gemini/config/plugins/beacon-sdd/hooks/|g' \
      "$f" > "$tmp"

    local name
    for name in "${skill_names[@]}"; do
      sed -i '' -e "s|\\.claude/skills/${name}/|~/.gemini/config/plugins/beacon-sdd/skills/${name}/|g" "$tmp"
    done
    mv "$tmp" "$f"
  done < <(find "$dest" -type f -print0 2>/dev/null)
}

install_antigravity_plugin() {
  local plugin stamp dest_stamp
  plugin="$(antigravity_plugin_root)"
  stamp="$(antigravity_plugin_source_stamp)"
  dest_stamp="$plugin/.sdd-source-stamp"

  if [[ -f "$dest_stamp" && "$(cat "$dest_stamp")" == "$stamp" ]]; then
    echo "    plugin $ANTIGRAVITY_PLUGIN_NAME already installed (source unchanged)"
    return 0
  fi

  echo "    sync Antigravity plugin → $plugin"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: would write plugin tree ($plugin) and stamp"
    return 0
  fi

  mkdir -p "$plugin" "$plugin/skills" "$plugin/rules" "$plugin/hooks" "$plugin/agents"
  rm -rf "$plugin/skills" "$plugin/rules" "$plugin/hooks" "$plugin/agents"
  mkdir -p "$plugin/skills" "$plugin/rules" "$plugin/hooks" "$plugin/agents"

  cp "$SRC/adapters/antigravity/plugin.json" "$plugin/plugin.json"
  cp "$SRC/adapters/antigravity/hooks.json" "$plugin/hooks.json"
  cp -R "$SRC/adapters/antigravity/rules/"* "$plugin/rules/"
  cp -R "$SRC/hooks/"* "$plugin/hooks/"
  cp -R "$SRC/skills/"* "$plugin/skills/"
  cp -R "$SRC/agents/"* "$plugin/agents/"

  # Map personas from agents/ into skills/<agent>/SKILL.md if not already present as a skill
  local agent_file agent_name
  for agent_file in "$SRC/agents"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_name="$(basename "$agent_file" .md)"
    if [[ ! -d "$plugin/skills/$agent_name" ]]; then
      mkdir -p "$plugin/skills/$agent_name"
      cp "$agent_file" "$plugin/skills/$agent_name/SKILL.md"
    fi
  done

  chmod +x "$plugin/hooks/"*.sh 2>/dev/null || true
  adapt_antigravity_paths "$plugin"
  printf '%s\n' "$stamp" > "$dest_stamp"
  echo "    installed $ANTIGRAVITY_PLUGIN_NAME globally (~/.gemini/config/plugins/$ANTIGRAVITY_PLUGIN_NAME)"
}

install_antigravity() {
  echo "==> Installing Antigravity adapter → global user plugin + workspace control files"

  install_agents_md

  # If legacy .agent stub was previously managed, prune it
  if [[ -f "$ROOT/.agent/.agentic-managed" ]]; then
    deactivate_managed_runtime "$ROOT/.agent" "legacy .agent stub"
  fi

  install_antigravity_plugin

  install_adapter_docs "antigravity"
  echo "    done (plugin is global at ~/.gemini/config/plugins/$ANTIGRAVITY_PLUGIN_NAME)"
}

case "$TARGET" in
  claude) install_claude ;;
  cursor) install_cursor ;;
  antigravity) install_antigravity ;;
  all)
    # Claude framework is the user plugin. Cursor is .cursor/ only.
    # Do not keep a project .claude/ framework mirror (it overrides the plugin).
    install_claude
    install_cursor
    install_antigravity
    ;;
  *)
    echo "error: unknown target '$TARGET'" >&2
    usage
    exit 2
    ;;
esac

# .gitignore merge=union lives in .gitattributes (the built-in driver is
# selected by that attribute, not by a custom merge.<name>.driver config).
# Re-running setup restores the line if a merge dropped it.
ensure_gitignore_merge_union() {
  local attr="$ROOT/.gitattributes"
  local line='.gitignore merge=union'
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY: ensure '$line' in .gitattributes"
    return
  fi
  if [[ -f "$attr" ]] && grep -qxF "$line" "$attr"; then
    echo "    .gitattributes already sets .gitignore merge=union"
    return
  fi
  printf '\n# Union .gitignore when merging this SDD into a project repo.\n%s\n' "$line" >> "$attr"
  echo "    wrote .gitignore merge=union into .gitattributes"
}

ensure_gitignore_merge_union

echo "OK: setup-agentic ($TARGET) finished."
