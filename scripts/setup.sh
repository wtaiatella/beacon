#!/usr/bin/env bash
# Post-clone setup for agentic-workspace. Idempotent: safe to re-run.
# Validates relationships (hooks.json ↔ scripts, agents ↔ frontmatter) instead
# of hardcoded counts. Reports what exists rather than what "should" exist.
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
  NODE_MAJOR="$(node -p 'parseInt(process.versions.node.split(".")[0], 10)')"
  if [[ "$NODE_MAJOR" -ge 18 ]]; then pass "Node.js $(node -v) (>= 18)"
  else fail "Node.js $(node -v) — need >= 18"; PREREQ_OK=0; fi
else fail "Node.js not found — required (>= 18)"; PREREQ_OK=0; fi

if command -v git &>/dev/null; then pass "git $(git --version | sed 's/git version //')"
else fail "git not found — required"; PREREQ_OK=0; fi

CURSOR_OK=0
if command -v cursor &>/dev/null; then pass "Cursor CLI: $(command -v cursor)"; CURSOR_OK=1
elif [[ "$(uname -s)" == "Darwin" ]] && [[ -d "/Applications/Cursor.app" ]]; then
  pass "Cursor IDE: /Applications/Cursor.app"; CURSOR_OK=1
else warn "Cursor CLI or IDE not detected — install from https://cursor.com"; fi

[[ "$PREREQ_OK" -eq 1 ]] || { echo ""; fail "Fix prerequisites, then re-run."; exit 1; }

# --- 2. Executable bits & runtime dirs ---
chmod +x scripts/tools/*.sh .cursor/hooks/*.sh scripts/setup.sh scripts/upgrade.sh 2>/dev/null || true
mkdir -p docs/specs docs/sessions
pass "Runtime dirs: docs/specs, docs/sessions"

# --- 3. Workspace integrity (relationship-based, no hardcoded counts) ---
echo ""
echo "Workspace integrity"

# Router rule
RULE="$ROOT/.cursor/rules/00-workspace-router.mdc"
if [[ -f "$RULE" ]] && [[ "$(grep -c '^---$' "$RULE" || true)" -ge 2 ]]; then
  pass "Router rule: frontmatter valid"
else fail "Router rule missing or bad frontmatter: $RULE"; fi

# Agents: count + validate every agent has required frontmatter fields
AGENT_N=$(find "$ROOT/.cursor/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
AGENT_VALID=0
shopt -s nullglob
for f in "$ROOT"/.cursor/agents/*.md; do
  FM=$(sed -n '/^---$/,/^---$/p' "$f" | head -20)
  HAS_NAME=$(echo "$FM" | grep -c '^name:' || true)
  HAS_DESC=$(echo "$FM" | grep -c '^description:' || true)
  HAS_MODEL=$(echo "$FM" | grep -c '^model:' || true)
  if [[ "$HAS_NAME" -gt 0 && "$HAS_DESC" -gt 0 && "$HAS_MODEL" -gt 0 ]]; then
    AGENT_VALID=$((AGENT_VALID + 1))
  else
    fail "Agent $(basename "$f"): missing name/description/model in frontmatter"
  fi
done
shopt -u nullglob
pass "Agents: $AGENT_N found, $AGENT_VALID with valid frontmatter"

# Skills: count + validate frontmatter
SKILL_N=$(find "$ROOT/.cursor/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
for f in $(find "$ROOT/.cursor/skills" -name 'SKILL.md' 2>/dev/null); do
  FM=$(sed -n '/^---$/,/^---$/p' "$f" | head -10)
  if ! echo "$FM" | grep -q '^name:'; then
    fail "Skill $(echo "$f" | sed "s|$ROOT/||"): missing name in frontmatter"
  fi
done
pass "Skills: $SKILL_N found, all with valid frontmatter"

# JSON files
for j in .cursor/mcp.json .cursor/hooks.json .cursor/settings.json; do
  if [[ -f "$ROOT/$j" ]]; then
    node -e "JSON.parse(require('fs').readFileSync('$ROOT/$j','utf8'))" 2>/dev/null \
      && pass "$j: valid JSON" \
      || fail "$j: invalid JSON"
  else
    warn "$j: missing (optional — create for team defaults; see docs/reference/atlassian-cursor-workflow.md)"
  fi
done

# Optional: Atlassian MCP (informational only — do not fail setup)
if [[ -f "$ROOT/.cursor/mcp.json" ]]; then
  if ! node -e "
    const j = JSON.parse(require('fs').readFileSync('$ROOT/.cursor/mcp.json','utf8'));
    const s = j.mcpServers || {};
    const keys = Object.keys(s);
    const hasAtlassian = keys.some(function (k) { return /atlassian/i.test(k); });
    process.exit(hasAtlassian ? 0 : 1);
  " 2>/dev/null; then
    warn "Optional Atlassian MCP: no server name matching 'Atlassian' in .cursor/mcp.json — Jira/Confluence read tools need config + auth (docs/reference/atlassian-cursor-workflow.md)"
  else
    pass "Optional Atlassian MCP: entry present in mcp.json (confirm OAuth under Settings → MCP)"
  fi
fi

# Optional: Glean MCP (informational only — do not fail setup)
if [[ -f "$ROOT/.cursor/mcp.json" ]]; then
  if ! node -e "
    const j = JSON.parse(require('fs').readFileSync('$ROOT/.cursor/mcp.json','utf8'));
    const s = j.mcpServers || {};
    const keys = Object.keys(s);
    const hasGlean = keys.some(function (k) { return /glean/i.test(k); });
    process.exit(hasGlean ? 0 : 1);
  " 2>/dev/null; then
    warn "Optional Glean MCP: no server name matching 'Glean' in .cursor/mcp.json — enterprise search needs config + auth (docs/reference/glean-cursor-workflow.md)"
  else
    pass "Optional Glean MCP: entry present in mcp.json (confirm URL/token under Settings → MCP)"
  fi
fi

# Hooks: bidirectional sync between hooks.json and .cursor/hooks/*.sh
HOOK_SCRIPTS=$(find "$ROOT/.cursor/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
HOOK_REGISTERED=$(node -e "
  const h=JSON.parse(require('fs').readFileSync('$ROOT/.cursor/hooks.json','utf8'));
  const cmds=new Set();
  for(const ev of Object.values(h.hooks||{})){for(const e of ev){cmds.add(e.command)}}
  cmds.forEach(c=>console.log(c));
" 2>/dev/null)
HOOK_REG_COUNT=$(echo "$HOOK_REGISTERED" | grep -c '.' || true)
HOOK_ISSUES=0
while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue
  if [[ ! -f "$ROOT/$cmd" ]]; then
    fail "hooks.json references $cmd but file does not exist"
    HOOK_ISSUES=$((HOOK_ISSUES + 1))
  fi
done <<< "$HOOK_REGISTERED"
for f in "$ROOT"/.cursor/hooks/*.sh; do
  REL=".cursor/hooks/$(basename "$f")"
  if ! echo "$HOOK_REGISTERED" | grep -q "$REL"; then
    warn "Hook script $REL exists but is NOT registered in hooks.json"
  fi
  if [[ ! -x "$f" ]]; then
    fail "Hook script $REL is not executable"
    HOOK_ISSUES=$((HOOK_ISSUES + 1))
  fi
done
if [[ "$HOOK_ISSUES" -eq 0 ]]; then
  pass "Hooks: $HOOK_SCRIPTS scripts, $HOOK_REG_COUNT registered in hooks.json, all synced"
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

# upgrade.sh
if [[ -f "$ROOT/scripts/upgrade.sh" && -x "$ROOT/scripts/upgrade.sh" ]]; then
  pass "scripts/upgrade.sh: present and executable"
else
  fail "scripts/upgrade.sh must exist and be executable"
fi

# Version (from git tags)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
pass "Version: $LATEST_TAG (from git tags)"

# --- 4. Summary ---
echo ""
pass "Summary: $AGENT_N agents, $SKILL_N skills, $HOOK_SCRIPTS hooks, $TOOL_N tool scripts"

# --- 5. Next steps ---
echo ""
echo "Next steps"
printf '%s\n' \
  "  • Clone your target repos inside this workspace" \
  "  • Open in Cursor: cursor ." \
  "  • Verify agents are loaded: check Cursor Settings > Rules and Agents" \
  '  • Try: /plan myapp/ "add user auth"' \
  "  • Optional: GitLab MCP is @zereight/mcp-gitlab in ~/.cursor/mcp.json (SCM API + PAT) — docs/reference/gitlab-cursor-workflow.md" \
  "  • Optional: Atlassian MCP (Jira/Confluence read) — docs/reference/atlassian-cursor-workflow.md" \
  "  • Optional: Glean MCP (enterprise search) — set GLEAN_MCP_URL + auth; docs/reference/glean-cursor-workflow.md"
[[ "$CURSOR_OK" -eq 1 ]] || warn "Install Cursor CLI or IDE when ready."
[[ "$ERRORS" -eq 0 ]] || { echo ""; fail "$ERRORS issue(s) found — fix before proceeding."; exit 1; }
