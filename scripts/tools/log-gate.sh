#!/usr/bin/env bash
# Append GATE: / impl | / FAILURE: lines via session-memory.sh from workspace root (no cd chains).
# Resolves ACTIVE_SESSION through session-memory.sh (fails if no session when writing).
# Bash 3.2+ compatible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SM="$ROOT/scripts/tools/session-memory.sh"

usage() {
  cat <<'EOF'
Usage: log-gate.sh <subcommand> [args ...]

Subcommands (run-pipeline telemetry):
  plan-attempt <n> <spec-path>
      → session-memory write 'GATE: plan | ATTEMPT n | spec: <path>'
  plan-review-gate <score> <decision> <attempts>
      → 'GATE: plan-review | <score>% | <decision> | attempts: n'
  plan-done <spec-path>
      → 'GATE: plan | DONE | spec: <path>'
  impl-start [--phase <k>] --domain <dev|sre|data>
      → 'impl | START | phase: k | domain: …'  (omit phase line if no --phase)
  impl-done --spec <path> [--phase <k>] [--domains <dev,sre,data>]
      → 'GATE: impl | DONE | phase: k | spec: …' or 'GATE: impl | DONE | spec: …' (matches --resume checkpoints)
  impl-review-gate <score> <decision> [--phase <k>] --spec <path> [--attempts <n>]
  impl-phase-done [--phase <k>] --spec <path>
      → same GATE line as impl-done (prefer impl-done; impl-phase-done kept for compatibility)
  final-scrum <decision>
      → 'GATE: final-scrum | <decision>'
  failure <step> <message>
      → 'FAILURE: step | message'
  manual-gate-context <segment> <message...>
      → 'MANUAL_GATE_CONTEXT: <segment> | <text>' (see --manual step gates)
  write-raw "<line>"
      → session-memory write with exact line (escape quotes in shell)

  -h, --help   This help.

All writes go through scripts/tools/session-memory.sh from repo root.
EOF
}

ensure_session() {
  if ! "$SM" active-path >/dev/null 2>&1; then
    echo "log-gate: no active session — run pipeline-init / session-memory begin-run first" >&2
    exit 1
  fi
}

cd "$ROOT"

cmd="${1:-}"
if [ -z "$cmd" ] || [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ]; then
  usage
  exit 0
fi
shift

case "$cmd" in
  plan-attempt)
    [ $# -eq 2 ] || { echo "log-gate: plan-attempt <n> <spec-path>" >&2; exit 1; }
    ensure_session
    "$SM" write "GATE: plan | ATTEMPT $1 | spec: $2"
    ;;
  plan-review-gate)
    [ $# -eq 3 ] || { echo "log-gate: plan-review-gate <score> <decision> <attempts>" >&2; exit 1; }
    ensure_session
    "$SM" write "GATE: plan-review | $1% | $2 | attempts: $3"
    ;;
  plan-done)
    [ $# -eq 1 ] || { echo "log-gate: plan-done <spec-path>" >&2; exit 1; }
    ensure_session
    "$SM" write "GATE: plan | DONE | spec: $1"
    ;;
  impl-start)
    PHASE=""
    DOM=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --phase)
          [ $# -ge 2 ] || exit 1
          PHASE="$2"
          shift 2
          ;;
        --domain)
          [ $# -ge 2 ] || exit 1
          DOM="$2"
          shift 2
          ;;
        *) echo "log-gate: impl-start: unknown arg $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$DOM" ] || { echo "log-gate: impl-start requires --domain" >&2; exit 1; }
    ensure_session
    if [ -n "$PHASE" ]; then
      "$SM" write "impl | START | phase: $PHASE | domain: $DOM"
    else
      "$SM" write "impl | START | domain: $DOM"
    fi
    ;;
  impl-done)
    SPEC=""
    PHASE=""
    DOMAINS=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --spec)
          [ $# -ge 2 ] || exit 1
          SPEC="$2"
          shift 2
          ;;
        --phase)
          [ $# -ge 2 ] || exit 1
          PHASE="$2"
          shift 2
          ;;
        --domains)
          [ $# -ge 2 ] || exit 1
          DOMAINS="$2"
          shift 2
          ;;
        *) echo "log-gate: impl-done: unknown arg $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$SPEC" ] || { echo "log-gate: impl-done requires --spec" >&2; exit 1; }
    ensure_session
    LINE=""
    if [ -n "$PHASE" ]; then
      LINE="GATE: impl | DONE | phase: $PHASE | spec: $SPEC"
    else
      LINE="GATE: impl | DONE | spec: $SPEC"
    fi
    if [ -n "$DOMAINS" ]; then
      LINE="$LINE | domains: $DOMAINS"
    fi
    "$SM" write "$LINE"
    ;;
  impl-review-gate)
    SCORE=""
    DEC=""
    PHASE=""
    SPEC=""
    ATT=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --phase)
          [ $# -ge 2 ] || exit 1
          PHASE="$2"
          shift 2
          ;;
        --spec)
          [ $# -ge 2 ] || exit 1
          SPEC="$2"
          shift 2
          ;;
        --attempts)
          [ $# -ge 2 ] || exit 1
          ATT="$2"
          shift 2
          ;;
        *)
          if [ -z "$SCORE" ]; then SCORE="$1"; shift
          elif [ -z "$DEC" ]; then DEC="$1"; shift
          else echo "log-gate: impl-review-gate: unexpected arg $1" >&2; exit 1
          fi
          ;;
      esac
    done
    [ -n "$SCORE" ] && [ -n "$DEC" ] && [ -n "$SPEC" ] || {
      echo "log-gate: impl-review-gate <score> <decision> [--phase k] --spec path [--attempts n]" >&2
      exit 1
    }
    ensure_session
    LINE="impl-review | GATE | ${SCORE}% | ${DEC}"
    if [ -n "$PHASE" ]; then
      LINE="$LINE | phase: $PHASE"
    fi
    LINE="$LINE | spec: $SPEC"
    if [ -n "$ATT" ]; then
      LINE="$LINE | attempts: $ATT"
    fi
    "$SM" write "$LINE"
    ;;
  impl-phase-done)
    SPEC=""
    PHASE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --spec)
          [ $# -ge 2 ] || exit 1
          SPEC="$2"
          shift 2
          ;;
        --phase)
          [ $# -ge 2 ] || exit 1
          PHASE="$2"
          shift 2
          ;;
        *) echo "log-gate: impl-phase-done: unknown arg $1" >&2; exit 1 ;;
      esac
    done
    [ -n "$SPEC" ] || { echo "log-gate: impl-phase-done requires --spec" >&2; exit 1; }
    ensure_session
    if [ -n "$PHASE" ]; then
      "$SM" write "GATE: impl | DONE | phase: $PHASE | spec: $SPEC"
    else
      "$SM" write "GATE: impl | DONE | spec: $SPEC"
    fi
    ;;
  final-scrum)
    [ $# -eq 1 ] || { echo "log-gate: final-scrum <decision>" >&2; exit 1; }
    ensure_session
    "$SM" write "GATE: final-scrum | $1"
    ;;
  failure)
    [ $# -ge 2 ] || { echo "log-gate: failure <step> <message...>" >&2; exit 1; }
    STEP="$1"
    shift
    MSG="$*"
    ensure_session
    "$SM" write "FAILURE: $STEP | $MSG"
    ;;
  manual-gate-context)
    [ $# -ge 2 ] || { echo "log-gate: manual-gate-context <segment> <message...>" >&2; exit 1; }
    SEG="$1"
    shift
    REST="$*"
    ensure_session
    "$SM" write "MANUAL_GATE_CONTEXT: $SEG | $REST"
    ;;
  write-raw)
    [ $# -ge 1 ] || { echo 'log-gate: write-raw "<line>"' >&2; exit 1; }
    ensure_session
    "$SM" write "$*"
    ;;
  *)
    echo "log-gate: unknown subcommand: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac

exit 0
