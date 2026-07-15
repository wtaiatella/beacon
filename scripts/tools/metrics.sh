#!/usr/bin/env bash
# Local metrics aggregation for the agentic workspace. Reads audit.log and
# session memory to produce per-agent, per-spec, and pipeline health metrics.
# All data stays local — nothing leaves the machine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT/docs/audit.log"
SESSIONS="$ROOT/docs/sessions"

usage() {
  cat <<'EOF'
Usage: metrics.sh [command]

Commands:
  overview      Pipeline health summary (default)
  agents        Per-agent invocation counts and rework rates
  specs         Per-spec pipeline metrics (scores, iterations, duration)
  gates         Gate decision history (PROCEED / REWORK / ASK_USER / ESCALATE)
  sessions      Session duration and frequency
  models        Model tier usage, distribution, and escalation frequency
  --help, -h    Show this help

All metrics are derived from local files (docs/audit.log, docs/sessions/).
Nothing leaves the machine.
EOF
}

CMD="${1:-overview}"
case "$CMD" in
  -h|--help) usage; exit 0 ;;
esac

# --- helpers ---

no_data() {
  echo "No data found. Metrics are derived from docs/audit.log and docs/sessions/."
  echo "Run some pipelines first, then check back."
  exit 0
}

audit_lines() {
  [[ -f "$AUDIT" ]] && cat "$AUDIT" || true
}

session_gate_lines() {
  find "$SESSIONS" -name '*.md' -type f 2>/dev/null | while read -r f; do
    grep -h '^\- .*|.*GATE:' "$f" 2>/dev/null || true
    grep -h '^\- .*|.*DECISION:' "$f" 2>/dev/null || true
    grep -h '^\- .*|.*PIPELINE:' "$f" 2>/dev/null || true
    grep -h '^\- .*|.*FAILURE:' "$f" 2>/dev/null || true
  done
}

# --- overview ---

cmd_overview() {
  echo "═══ Workspace Metrics (local) ═══"
  echo ""

  local total_sessions=0 total_gates=0 total_blocks=0
  if [[ -f "$AUDIT" ]]; then
    total_sessions=$(wc -l < "$AUDIT" | tr -d ' ')
    total_blocks=$(grep -c 'blocked\|block' "$AUDIT" 2>/dev/null || true)
  fi

  local gate_data
  gate_data=$(session_gate_lines)
  if [[ -n "$gate_data" ]]; then
    total_gates=$(echo "$gate_data" | grep -c 'GATE:' 2>/dev/null || true)
  fi

  local proceed=0 rework=0 ask=0 escalate=0
  if [[ -n "$gate_data" ]]; then
    proceed=$(echo "$gate_data" | grep -ci 'PROCEED' 2>/dev/null || true)
    rework=$(echo "$gate_data" | grep -ci 'REWORK' 2>/dev/null || true)
    ask=$(echo "$gate_data" | grep -ci 'ASK_USER' 2>/dev/null || true)
    escalate=$(echo "$gate_data" | grep -ci 'ESCALATE' 2>/dev/null || true)
  fi

  local completions=0 failures=0
  if [[ -n "$gate_data" ]]; then
    completions=$(echo "$gate_data" | grep -c 'PIPELINE: COMPLETE' 2>/dev/null || true)
    failures=$(echo "$gate_data" | grep -c 'FAILURE:' 2>/dev/null || true)
  fi

  echo "Sessions logged:        $total_sessions"
  echo "Gate decisions:          $total_gates"
  echo "  PROCEED:               $proceed"
  echo "  REWORK:                $rework"
  echo "  ASK_USER:              $ask"
  echo "  ESCALATE:              $escalate"
  echo ""
  echo "Pipeline completions:    $completions"
  echo "Pipeline failures:       $failures"
  echo "Security blocks:         $total_blocks"
  echo ""

  if [[ "$total_gates" -gt 0 ]]; then
    local first_pass_pct=0
    if command -v bc &>/dev/null; then
      first_pass_pct=$(echo "scale=0; $proceed * 100 / $total_gates" | bc 2>/dev/null || echo "?")
    else
      first_pass_pct=$(( proceed * 100 / total_gates ))
    fi
    echo "First-pass rate:         ${first_pass_pct}% (PROCEED / total gates)"
  fi

  if [[ "$total_sessions" -eq 0 && "$total_gates" -eq 0 ]]; then
    echo ""
    no_data
  fi
}

# --- agents ---

cmd_agents() {
  echo "═══ Agent Metrics (local) ═══"
  echo ""

  local gate_data
  gate_data=$(session_gate_lines)
  [[ -z "$gate_data" ]] && no_data

  echo "Gate results by step:"
  echo ""
  printf "%-20s %8s %8s %8s %8s\n" "Step" "PROCEED" "REWORK" "ASK" "ESCL"
  printf "%-20s %8s %8s %8s %8s\n" "────────────────────" "────────" "────────" "────────" "────────"

  for step in plan plan-review impl impl-review qa summary; do
    local p r a e
    p=$(echo "$gate_data" | grep "GATE: $step" | grep -ci 'PROCEED' 2>/dev/null || true)
    r=$(echo "$gate_data" | grep "GATE: $step" | grep -ci 'REWORK' 2>/dev/null || true)
    a=$(echo "$gate_data" | grep "GATE: $step" | grep -ci 'ASK_USER' 2>/dev/null || true)
    e=$(echo "$gate_data" | grep "GATE: $step" | grep -ci 'ESCALATE' 2>/dev/null || true)
    local total=$((p + r + a + e))
    [[ "$total" -eq 0 ]] && continue
    printf "%-20s %8d %8d %8d %8d\n" "$step" "$p" "$r" "$a" "$e"
  done

  echo ""

  if [[ -f "$AUDIT" ]]; then
    local blocked
    blocked=$(grep -c 'blocked\|block' "$AUDIT" 2>/dev/null || true)
    if [[ "$blocked" -gt 0 ]]; then
      echo "Security blocks:         $blocked"
      echo ""
      echo "Recent blocks:"
      grep 'blocked\|block' "$AUDIT" | tail -5 | while read -r line; do
        echo "  $line"
      done
    fi
  fi
}

# --- specs ---

cmd_specs() {
  echo "═══ Spec Metrics (local) ═══"
  echo ""

  local specdir="$ROOT/docs/specs"
  if [[ ! -d "$specdir" ]] || ! ls "$specdir"/*.md &>/dev/null 2>&1; then
    echo "No specs found in docs/specs/."
    exit 0
  fi

  printf "%-40s %-12s %10s %12s\n" "Spec" "Status" "Progress" "Last Updated"
  printf "%-40s %-12s %10s %12s\n" "────────────────────────────────────────" "────────────" "──────────" "────────────"

  for f in "$specdir"/*.md; do
    local name status last_updated checked total
    name=$(basename "$f" .md)
    status=$(sed -n '/^---$/,/^---$/p' "$f" | grep '^status:' | head -1 | sed 's/status:\s*//' | tr -d ' ')
    last_updated=$(sed -n '/^---$/,/^---$/p' "$f" | grep '^last-updated:' | head -1 | sed 's/last-updated:\s*//' | tr -d ' ')
    checked=$(grep -c '^\- \[x\]' "$f" 2>/dev/null || true)
    total=$(grep -c '^\- \[.\]' "$f" 2>/dev/null || true)
    printf "%-40s %-12s %5s/%-4s %12s\n" "$name" "${status:-?}" "$checked" "$total" "${last_updated:-?}"
  done

  echo ""

  local gate_data
  gate_data=$(session_gate_lines)
  if [[ -n "$gate_data" ]]; then
    local scores
    scores=$(echo "$gate_data" | grep -oE '[0-9]+%' 2>/dev/null || true)
    if [[ -n "$scores" ]]; then
      local count avg sum=0
      count=$(echo "$scores" | wc -l | tr -d ' ')
      while read -r s; do
        local num="${s%\%}"
        sum=$((sum + num))
      done <<< "$scores"
      avg=$((sum / count))
      echo "Average gate score:      ${avg}% (across $count gate decisions)"
    fi
  fi
}

# --- gates ---

cmd_gates() {
  echo "═══ Gate Decision History (local) ═══"
  echo ""

  local gate_data
  gate_data=$(session_gate_lines)
  [[ -z "$gate_data" ]] && no_data

  echo "$gate_data" | grep 'GATE:\|PIPELINE:\|FAILURE:' | while read -r line; do
    echo "  $line"
  done
}

# --- sessions ---

cmd_sessions() {
  echo "═══ Session Metrics (local) ═══"
  echo ""

  if [[ ! -f "$AUDIT" ]]; then
    no_data
  fi

  local total
  total=$(wc -l < "$AUDIT" | tr -d ' ')
  echo "Total sessions:          $total"

  local completed aborted
  completed=$(grep -ci 'completed' "$AUDIT" 2>/dev/null || true)
  aborted=$(grep -ci 'aborted\|error\|failed' "$AUDIT" 2>/dev/null || true)
  echo "Completed:               $completed"
  echo "Aborted/errored:         $aborted"
  echo ""

  echo "Recent sessions (last 10):"
  tail -10 "$AUDIT" | while read -r line; do
    echo "  $line"
  done
}

# --- models ---

cmd_models() {
  echo "═══ Model Usage Metrics (local) ═══"
  echo ""

  if [[ ! -f "$AUDIT" ]]; then
    no_data
  fi

  # Count model tier usage from 5th column of audit.log (tab-separated).
  # Uses simple counters instead of associative arrays for bash 3.2 compatibility.
  local has_tiers=false
  local cnt_nano=0 cnt_economy=0 cnt_standard=0 cnt_premium=0 cnt_max=0

  while IFS=$'\t' read -r _ts _sid _reason _dur tier_val; do
    tier_val=$(echo "$tier_val" | tr -d '[:space:]')
    case "$tier_val" in
      nano)     has_tiers=true; cnt_nano=$((cnt_nano + 1)) ;;
      economy)  has_tiers=true; cnt_economy=$((cnt_economy + 1)) ;;
      standard) has_tiers=true; cnt_standard=$((cnt_standard + 1)) ;;
      premium)  has_tiers=true; cnt_premium=$((cnt_premium + 1)) ;;
      max)      has_tiers=true; cnt_max=$((cnt_max + 1)) ;;
      "") ;;
      *) ;; # ignore unrecognized tier values
    esac
  done < "$AUDIT"

  if [[ "$has_tiers" == false ]]; then
    echo "No model tier data found in audit log."
    echo "Model tier tracking requires the extended audit log format (5th column)."
    echo "New sessions will include model tier data automatically."
    exit 0
  fi

  echo "Model Tier Distribution:"
  echo ""
  printf "%-12s %8s\n" "Tier" "Sessions"
  printf "%-12s %8s\n" "────────────" "────────"
  [[ "$cnt_nano"     -gt 0 ]] && printf "%-12s %8d\n" "nano"     "$cnt_nano"
  [[ "$cnt_economy"  -gt 0 ]] && printf "%-12s %8d\n" "economy"  "$cnt_economy"
  [[ "$cnt_standard" -gt 0 ]] && printf "%-12s %8d\n" "standard" "$cnt_standard"
  [[ "$cnt_premium"  -gt 0 ]] && printf "%-12s %8d\n" "premium"  "$cnt_premium"
  [[ "$cnt_max"      -gt 0 ]] && printf "%-12s %8d\n" "max"      "$cnt_max"

  echo ""

  # Escalation frequency from session memory
  local gate_data
  gate_data=$(session_gate_lines)
  if [[ -n "$gate_data" ]]; then
    local escalations
    escalations=$(echo "$gate_data" | grep -c 'MODEL_ESCALATION' 2>/dev/null || true)
    escalations=${escalations:-0}
    echo "Model escalations:       $escalations"
    if [[ "$escalations" -gt 0 ]]; then
      echo ""
      echo "Recent escalations:"
      echo "$gate_data" | grep 'MODEL_ESCALATION' | tail -5 | while read -r line; do
        echo "  $line"
      done
    fi
  fi
}

# --- dispatch ---

case "$CMD" in
  overview)  cmd_overview ;;
  agents)    cmd_agents ;;
  specs)     cmd_specs ;;
  gates)     cmd_gates ;;
  sessions)  cmd_sessions ;;
  models)    cmd_models ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage >&2
    exit 1
    ;;
esac
