#!/usr/bin/env bash
# Post-clone setup for agentic-workspace on CLAUDE CODE. Idempotent: safe to re-run.
# Validates the .claude/ structure (agents, commands, skills, hooks) and settings.json
# ↔ hook-script relationships, instead of hardcoded counts. Reports what exists.
# For the Cursor variant, use scripts/setup.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

G='\033[0;32m' Y='\033[0;33m' R='\033[0;31m' N='\033[0m'
ERRORS=0
pass() { echo -e "${G}✓${N} $*"; }
warn() { echo -e "${Y}⚠${N} $*"; }
fail() { echo -e "${R}✗${N} $*"; ERRORS=$((ERRORS + 1)); }

# --- 1. Prerequisites ---
PREREQ_OK=1
echo "Prerequisites"
if command -v node &>/dev/null; then
  # Use `node -e` + write (not `node -p`, which colorizes via util.inspect under
  # FORCE_COLOR) and strip any stray non-digits so the numeric test is robust.
  NODE_MAJOR="$(node -e 'process.stdout.write(String(parseInt(process.versions.node.split(".")[0],10)))' 2>/dev/null | tr -cd '0-9')"
  if [[ -n "$NODE_MAJOR" && "$NODE_MAJOR" -ge 18 ]]; then pass "Node.js $(node -v) (>= 18)"
  else fail "Node.js $(node -v) — need >= 18"; PREREQ_OK=0; fi
else fail "Node.js not found — required (>= 18) for hook scripts"; PREREQ_OK=0; fi

if command -v git &>/dev/null; then pass "git $(git --version | sed 's/git version //')"
else fail "git not found — required"; PREREQ_OK=0; fi

CLAUDE_OK=0
if command -v claude &>/dev/null; then pass "Claude Code CLI: $(command -v claude)"; CLAUDE_OK=1
else warn "Claude Code CLI not detected — install from https://claude.com/claude-code (IDE extension also works)"; fi

[[ "$PREREQ_OK" -eq 1 ]] || { echo ""; fail "Fix prerequisites, then re-run."; exit 1; }

# --- 2. Executable bits & runtime dirs ---
chmod +x scripts/tools/*.sh .claude/hooks/*.sh scripts/setup.sh scripts/setup-claude.sh scripts/upgrade.sh 2>/dev/null || true
mkdir -p docs/specs
pass "Runtime dir: docs/specs"

# --- 3. Workspace integrity (relationship-based, no hardcoded counts) ---
echo ""
echo "Workspace integrity"

# Project memory (equivalent of the Cursor router rule)
if [[ -f "$ROOT/CLAUDE.md" ]]; then pass "CLAUDE.md: present (project context)"
else fail "CLAUDE.md missing — Claude Code has no always-on workspace context"; fi

# Subagents: count + validate every agent has required frontmatter fields
AGENT_N=$(find "$ROOT/.claude/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
AGENT_VALID=0
shopt -s nullglob
for f in "$ROOT"/.claude/agents/*.md; do
  FM=$(sed -n '/^---$/,/^---$/p' "$f" | head -20)
  HAS_NAME=$(echo "$FM" | grep -c '^name:' || true)
  HAS_DESC=$(echo "$FM" | grep -c '^description:' || true)
  if [[ "$HAS_NAME" -gt 0 && "$HAS_DESC" -gt 0 ]]; then
    AGENT_VALID=$((AGENT_VALID + 1))
  else
    fail "Agent $(basename "$f"): missing name/description in frontmatter"
  fi
done
shopt -u nullglob
pass "Subagents (.claude/agents): $AGENT_N found, $AGENT_VALID with valid frontmatter"

# Commands: count + validate frontmatter (description)
CMD_N=$(find "$ROOT/.claude/commands" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
shopt -s nullglob
for f in "$ROOT"/.claude/commands/*.md; do
  FM=$(sed -n '/^---$/,/^---$/p' "$f" | head -10)
  if ! echo "$FM" | grep -q '^description:'; then
    warn "Command $(basename "$f"): missing description in frontmatter"
  fi
done
shopt -u nullglob
pass "Commands (.claude/commands): $CMD_N found"

# Skills: count + validate frontmatter
SKILL_N=$(find "$ROOT/.claude/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
for f in $(find "$ROOT/.claude/skills" -name 'SKILL.md' 2>/dev/null); do
  FM=$(sed -n '/^---$/,/^---$/p' "$f" | head -10)
  if ! echo "$FM" | grep -q '^name:'; then
    fail "Skill $(echo "$f" | sed "s|$ROOT/||"): missing name in frontmatter"
  fi
done
pass "Skills (.claude/skills): $SKILL_N found, all with valid frontmatter"

# JSON files
for j in .mcp.json .claude/settings.json; do
  if [[ -f "$ROOT/$j" ]]; then
    node -e "JSON.parse(require('fs').readFileSync('$ROOT/$j','utf8'))" 2>/dev/null \
      && pass "$j: valid JSON" \
      || fail "$j: invalid JSON"
  else
    fail "$j: missing"
  fi
done

# Hooks: bidirectional sync between settings.json and .claude/hooks/*.sh
HOOK_SCRIPTS=$(find "$ROOT/.claude/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
HOOK_REGISTERED=$(node -e "
  const s=JSON.parse(require('fs').readFileSync('$ROOT/.claude/settings.json','utf8'));
  const cmds=new Set();
  for(const ev of Object.values(s.hooks||{})){
    for(const group of ev){
      for(const h of (group.hooks||[])){ if(h.command) cmds.add(h.command); }
    }
  }
  cmds.forEach(c=>console.log(c));
" 2>/dev/null)
HOOK_REG_COUNT=$(echo "$HOOK_REGISTERED" | grep -c '.' || true)
HOOK_ISSUES=0
while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  # Resolve $CLAUDE_PROJECT_DIR to ROOT for existence checking
  resolved="${cmd/\$CLAUDE_PROJECT_DIR/$ROOT}"
  resolved="${resolved/\$\{CLAUDE_PROJECT_DIR\}/$ROOT}"
  if [[ ! -f "$resolved" ]]; then
    fail "settings.json references $cmd but file does not exist"
    HOOK_ISSUES=$((HOOK_ISSUES + 1))
  fi
done <<< "$HOOK_REGISTERED"
for f in "$ROOT"/.claude/hooks/*.sh; do
  BASENAME="$(basename "$f")"
  if ! echo "$HOOK_REGISTERED" | grep -q "$BASENAME"; then
    warn "Hook script .claude/hooks/$BASENAME exists but is NOT registered in settings.json"
  fi
  if [[ ! -x "$f" ]]; then
    fail "Hook script .claude/hooks/$BASENAME is not executable"
    HOOK_ISSUES=$((HOOK_ISSUES + 1))
  fi
done
if [[ "$HOOK_ISSUES" -eq 0 ]]; then
  pass "Hooks: $HOOK_SCRIPTS scripts, $HOOK_REG_COUNT registered in settings.json, all synced"
fi

# Tool scripts: verify all executable
TOOL_N=$(find "$ROOT/scripts/tools" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
TOOL_NOT_EXEC=0
for f in "$ROOT"/scripts/tools/*.sh; do
  [[ ! -x "$f" ]] && { fail "$(basename "$f") is not executable"; TOOL_NOT_EXEC=$((TOOL_NOT_EXEC + 1)); }
done
if [[ "$TOOL_NOT_EXEC" -eq 0 ]]; then
  pass "Tool scripts: $TOOL_N found, all executable"
fi

# Version (from git tags)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
pass "Version: $LATEST_TAG (from git tags)"

# --- 4. Summary ---
echo ""
pass "Summary: $AGENT_N subagents, $CMD_N commands, $SKILL_N skills, $HOOK_SCRIPTS hooks, $TOOL_N tool scripts"

# --- 5. Next steps ---
echo ""
echo "Next steps"
printf '%s\n' \
  "  • Clone your target repos inside this workspace" \
  "  • Open in Claude Code: run 'claude' in this directory (or open the folder in your IDE)" \
  "  • Approve the project .mcp.json / settings.json when Claude Code prompts on first launch" \
  "  • Verify commands are loaded: type / and look for /plan, /dev, /run, ..." \
  "  • Verify hooks: run /hooks inside Claude Code" \
  '  • Try: /plan myapp/ "add user auth"' \
  "  • To add company MCP servers: edit .mcp.json"
[[ "$CLAUDE_OK" -eq 1 ]] || warn "Install the Claude Code CLI or IDE extension when ready."
[[ "$ERRORS" -eq 0 ]] || { echo ""; fail "$ERRORS issue(s) found — fix before proceeding."; exit 1; }
