#!/usr/bin/env bash
# Summarize Cursor chat-centric audit folders (docs/local/audit-cursor/).
# Legacy TSV (action-audit-cursor.tsv) is still readable as a fallback.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IDE="cursor"
TARGET=""

usage() {
  cat <<'EOF'
Usage: scripts/tools/tool-audit-summary.sh [--ide cursor] [session-id|path]

Default: summarize all chats under docs/local/audit-cursor/
Pass a session id or path to focus one chat (prints turns + actions).

Legacy: if no audit-cursor/ dirs exist, falls back to action-audit-cursor.tsv.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --ide)
      IDE="${2:-}"
      shift 2
      ;;
    --ide=*)
      IDE="${1#--ide=}"
      shift
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ "$IDE" != "cursor" && "$IDE" != "claude" ]]; then
  echo "tool-audit-summary: unknown --ide '$IDE' (use cursor|claude)" >&2
  exit 1
fi

AUDIT_ROOT="$ROOT/docs/local/audit-${IDE}"
LEGACY_TSV="$ROOT/docs/local/action-audit-${IDE}.tsv"

fmt_dur() {
  local ms="${1:-0}"
  ms=$((ms + 0))
  if (( ms <= 0 )); then echo "-"; return; fi
  local s=$((ms / 1000))
  if (( s < 60 )); then echo "${s}s"; return; fi
  local m=$((s / 60)); s=$((s % 60))
  if (( m < 60 )); then echo "${m}m${s}s"; return; fi
  local h=$((m / 60)); m=$((m % 60))
  echo "${h}h${m}m"
}

summarize_chat() {
  local dir="$1"
  local summary="$dir/summary.json"
  local turns="$dir/turns.jsonl"
  local actions="$dir/actions.jsonl"
  [[ -f "$summary" ]] || return 0

  python3 - "$summary" "$turns" "$actions" <<'PY'
import json, sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text())
turns_path = Path(sys.argv[2])
actions_path = Path(sys.argv[3])
turns = [json.loads(l) for l in turns_path.read_text().splitlines() if l.strip()] if turns_path.exists() else []
actions = [json.loads(l) for l in actions_path.read_text().splitlines() if l.strip()] if actions_path.exists() else []

def dur(ms):
    ms = int(ms or 0)
    if ms <= 0: return "-"
    s = ms // 1000
    if s < 60: return f"{s}s"
    m, s = divmod(s, 60)
    if m < 60: return f"{m}m{s}s"
    h, m = divmod(m, 60)
    return f"{h}h{m}m"

sid = summary.get("session_id", "?")
print(f"## chat {sid}")
print(
    f"turns={summary.get('turn_count', 0)}  actions={summary.get('action_count', 0)}  "
    f"tokens_api={summary.get('tokens_api_total', summary.get('tokens_est_total', 0))}  "
    f"spend=${summary.get('spend_dollars_total', 0)}  "
    f"(est_turns={summary.get('tokens_est_turns', '?')} est_actions={summary.get('tokens_est_actions', '?')})  "
    f"tools={summary.get('tool_events', 0)}  duration={dur(summary.get('duration_ms'))}"
)
if summary.get('billing_synced_at'):
    print(f"billing_synced_at={summary.get('billing_synced_at')}  events={summary.get('billing_events', '?')}")

print()
print("### turns")
print(f"{'#':<4} {'status':<8} {'tokens_api':>10} {'$':>7} {'est':>8} {'ev':>4} {'tools':>5}  prompt")
for t in turns:
    spend = t.get('spend_dollars')
    if spend is None and t.get('spend_cents') is not None:
        spend = (t.get('spend_cents') or 0) / 100
    print(
        f"{t.get('index', '?'):<4} {t.get('status',''):<8} "
        f"{t.get('tokens_api', 0):>10} {(spend if spend is not None else 0):>7.2f} "
        f"{t.get('tokens_est',0):>8} {t.get('billing_events',0):>4} {t.get('tool_events',0):>5}  "
        f"{(t.get('prompt_preview') or '')[:70]}"
    )
if actions:
    print()
    print("### actions")
    print(f"{'action':<22} {'status':<8} {'tokens_api':>10} {'$':>8} {'est':>8} {'tools':>6}  summary")
    for a in actions:
        spend = a.get('spend_dollars')
        if spend is None and a.get('spend_cents') is not None:
            spend = (a.get('spend_cents') or 0) / 100
        print(
            f"{(a.get('action') or '')[:22]:<22} {a.get('status',''):<8} "
            f"{a.get('tokens_api', a.get('tokens_est',0)):>10} "
            f"{(spend if spend is not None else 0):>8.2f} "
            f"{a.get('tokens_est',0):>8} {a.get('tool_events',0):>6}  "
            f"{(a.get('summary') or '')[:50]}"
        )
print()
PY
}

if [[ -n "$TARGET" ]]; then
  if [[ -d "$TARGET" ]]; then
    summarize_chat "$TARGET"
  elif [[ -d "$AUDIT_ROOT/$TARGET" ]]; then
    summarize_chat "$AUDIT_ROOT/$TARGET"
  elif [[ -d "$AUDIT_ROOT/$(basename "$TARGET")" ]]; then
    summarize_chat "$AUDIT_ROOT/$(basename "$TARGET")"
  else
    echo "tool-audit-summary: chat not found: $TARGET" >&2
    exit 1
  fi
  exit 0
fi

if [[ -d "$AUDIT_ROOT" ]] && compgen -G "$AUDIT_ROOT/*/" > /dev/null; then
  echo "IDE=$IDE  root=$AUDIT_ROOT"
  echo
  printf "%-38s %6s %8s %12s %10s %8s\n" "session" "turns" "actions" "tokens_api" "spend_$" "est_tot"
  python3 - "$AUDIT_ROOT" <<'PY'
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
rows = []
for d in sorted(root.iterdir()):
    sfile = d / "summary.json"
    if not sfile.exists():
        continue
    rows.append(json.loads(sfile.read_text()))

for s in rows:
    api = s.get('tokens_api_total', s.get('tokens_est_total', 0))
    spend = s.get('spend_dollars_total', 0) or 0
    print(
        f"{s.get('session_id','?'):<38} {s.get('turn_count',0):>6} {s.get('action_count',0):>8} "
        f"{api:>12} {spend:>10.2f} {s.get('tokens_est_total',0):>8}"
    )
print()
print(f"chats={len(rows)}  tokens_api_sum={sum(int(s.get('tokens_api_total') or s.get('tokens_est_total') or 0) for s in rows)}")
PY
  exit 0
fi

# Legacy TSV fallback
FILE="$LEGACY_TSV"
if [[ "$IDE" == "cursor" && ! -f "$FILE" && -f "$ROOT/docs/local/action-audit.tsv" ]]; then
  FILE="$ROOT/docs/local/action-audit.tsv"
fi
if [[ ! -f "$FILE" ]]; then
  echo "tool-audit-summary: no audit-cursor/ chats and no legacy TSV at $LEGACY_TSV" >&2
  exit 1
fi

echo "note: legacy TSV $FILE (new format: docs/local/audit-cursor/<session>/)" >&2
awk -F '\t' '
function fmt_dur(ms,   s,m,h) {
  ms = ms + 0
  if (ms <= 0) return "-"
  s = int(ms / 1000)
  if (s < 60) return s "s"
  m = int(s / 60); s = s % 60
  if (m < 60) return m "m" s "s"
  h = int(m / 60); m = m % 60
  return h "h" m "m"
}
NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
NF < 6 { next }
{
  total++
  action = ("action" in idx) ? $(idx["action"]) : "(unknown)"
  count[action]++
  dur[action] += (("duration_ms" in idx) ? $(idx["duration_ms"]) : 0) + 0
  tok[action] += (("tokens_total" in idx) ? $(idx["tokens_total"]) : 0) + 0
}
END {
  printf "%-24s %6s %12s %10s\n", "action", "rows", "tokens_sum", "duration"
  for (a in count) printf "%-24s %6d %12d %10s\n", a, count[a], tok[a], fmt_dur(dur[a])
  printf "\nrows=%d\n", total
}
' "$FILE"
