#!/usr/bin/env bash
# Summarize docs/local/tool-audit.tsv for Claude vs Cursor tool-call comparisons.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="${1:-$ROOT/docs/local/tool-audit.tsv}"

usage() {
  cat <<'EOF'
Usage: scripts/tools/tool-audit-summary.sh [tool-audit.tsv]

Prints total events, counts by tool/status, duration totals, and ordered sequence.
Use copied files such as docs/local/tool-audit-bcs-claude.tsv and
docs/local/tool-audit-bcs1-cursor.tsv for A/B comparison.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [[ ! -f "$FILE" ]]; then
  echo "tool-audit-summary: file not found: $FILE" >&2
  exit 1
fi

awk -F '\t' '
NR == 1 {
  for (i = 1; i <= NF; i++) idx[$i] = i
  next
}
NF < 8 { next }
{
  total++
  ide = $(idx["ide"])
  session = $(idx["session_id"])
  tool = $(idx["tool"])
  status = $(idx["status"])
  dur = $(idx["duration_ms"]) + 0
  summary = $(idx["summary"])

  if (tool == "Bash") tool = "Shell"
  if (tool == "ReadFile") tool = "Read"

  by_tool[tool]++
  by_status[status]++
  if (dur > 0) {
    duration_total += dur
    duration_count++
  }
  if (!(ide in seen_ide)) {
    seen_ide[ide] = 1
    ides = ides (ides ? "," : "") ide
  }
  if (!(session in seen_session)) {
    seen_session[session] = 1
    sessions = sessions (sessions ? "," : "") session
  }
  sequence = sequence sprintf("%04d %s %s %s\n", total, tool, status, summary)
}
END {
  print "file: " FILENAME
  print "ides: " (ides ? ides : "(none)")
  print "sessions: " (sessions ? sessions : "(none)")
  print "total_events: " total + 0
  print "duration_ms_total: " duration_total + 0
  if (duration_count > 0) printf("duration_ms_avg: %.0f\n", duration_total / duration_count)
  else print "duration_ms_avg: 0"

  print ""
  print "counts_by_tool:"
  for (t in by_tool) print "  " t "\t" by_tool[t]

  print ""
  print "counts_by_status:"
  for (s in by_status) print "  " s "\t" by_status[s]

  print ""
  print "sequence:"
  printf "%s", sequence
}
' "$FILE"
