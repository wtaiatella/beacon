#!/usr/bin/env bash
# Local multi-service sandbox for br-tax-engine + br-tax-ui: start/stop/inspect each
# datastore/process individually so /repro (and manual Postman/Swagger/UI testing) always
# run against an already-standing environment instead of re-deriving the local-dev recipe
# each time. Used by the /sandbox command.
#
# Usage: sandbox.sh --start|--stop|--status|--logs [service ... | all] [-f]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE_DIR="$ROOT/br-tax-engine"
UI_DIR="$ROOT/br-tax-ui"
STATE_DIR="$ROOT/.sandbox"
PID_DIR="$STATE_DIR/pids"
LOG_DIR="$STATE_DIR/logs"
SERVICES="mongo redis postgres engine mock swagger ui-proxy ui"

# Canonical boot order for --start's dependency cascade (see svc_deps below). mock comes before
# engine on purpose — starting engine first races a scheduled job against mock not being up yet
# (see Known gotchas in the skill doc). postgres is deliberately absent: never auto-started.
CASCADE_ORDER="mongo redis mock engine ui-proxy swagger ui"

mkdir -p "$PID_DIR" "$LOG_DIR"

# --- per-service metadata ------------------------------------------------------
# mongo/redis come from br-tax-engine's docker-compose.yml only (never br-tax-ui's — both
# repos define mongo:27017/redis:6379 and starting both stacks collides on those ports).

svc_kind() { case "$1" in
  mongo|redis) echo docker ;;
  postgres) echo native ;;
  *) echo process ;;
esac; }

svc_port() { case "$1" in
  mongo) echo 27017 ;;
  redis) echo 6379 ;;
  postgres) echo 5432 ;;
  engine) echo 3000 ;;
  mock) echo 3888 ;;
  swagger) echo 8000 ;;
  ui-proxy) echo 4000 ;;
  ui) echo 4200 ;;
esac; }

svc_dir() { case "$1" in
  engine|mock) echo "$ENGINE_DIR" ;;
  swagger) echo "$ENGINE_DIR/pecten" ;;
  ui-proxy|ui) echo "$UI_DIR" ;;
esac; }

svc_cmd() { case "$1" in
  engine) echo "npm start" ;;
  mock) echo "npm run mock:server" ;;
  swagger) echo "npm start" ;;
  ui-proxy) echo "npm run proxy:start" ;;
  ui) echo "npm start" ;;
esac; }

svc_timeout() { case "$1" in
  mongo|redis) echo 20 ;;
  engine|mock|ui-proxy) echo 40 ;;
  swagger|ui) echo 120 ;;
esac; }

svc_note() { case "$1" in
  mongo|redis) echo "shared datastore for both repos" ;;
  postgres) echo "native install — not managed by this script, status-only" ;;
  engine) echo "needs mongo+redis (+ your native postgres) up first for real calculations" ;;
  mock) echo "needed for /v3/token auth calls (else ECONNREFUSED to :3888)" ;;
  swagger) echo "pecten; regenerates OpenAPI JSON from YAML models on every start" ;;
  ui-proxy) echo "forwards to \$ENGINE_URL, defaults to http://localhost:3000" ;;
  ui) echo "ng serve, proxies via proxy.conf.json -> ui-proxy (:4000)" ;;
esac; }

# Flattened (not just direct) — every service this one needs end-to-end reachable to actually
# work, not only its immediate dependency. --start auto-cascades through these (except postgres,
# which is never auto-started); warn_missing_deps uses the same list as a final sanity check
# (catches postgres being down, or a cascade start that failed).
svc_deps() { case "$1" in
  engine) echo "mongo redis mock postgres" ;;
  swagger) echo "engine mongo redis mock postgres" ;;
  ui-proxy) echo "engine mongo redis mock postgres" ;;
  ui) echo "ui-proxy engine mongo redis mock postgres" ;;
  *) echo "" ;;
esac; }

# --- generic helpers ------------------------------------------------------------

port_open() {
  # lsof, not bash's /dev/tcp: on this workspace's dev machines, /dev/tcp can't reach IPv6-bound
  # listeners at all (confirmed — ng serve binds `localhost` on IPv6 here) while lsof reports
  # both families uniformly, matching what a browser/curl hitting "localhost:$1" actually sees.
  lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

pid_alive() {
  [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null
}

warn_missing_deps() {
  local svc="$1" dep missing=""
  for dep in $(svc_deps "$svc"); do
    port_open "$(svc_port "$dep")" || missing="$missing $dep"
  done
  if [ -n "$missing" ]; then
    echo "  [$svc] warning: not reachable yet —$missing. $svc may not work end-to-end until those are up too." >&2
  fi
}

wait_for_port() {
  local port="$1" timeout_s="$2" waited=0
  while ! port_open "$port"; do
    sleep 1
    waited=$((waited + 1))
    [ "$waited" -ge "$timeout_s" ] && return 1
  done
  return 0
}

compose() {
  ( cd "$ENGINE_DIR" && docker compose -f docker-compose.yml "$@" )
}

is_known_service() {
  local svc="$1" s
  for s in $SERVICES; do [ "$s" = "$svc" ] && return 0; done
  return 1
}

# --- docker services --------------------------------------------------------

docker_start() {
  local svc="$1" port timeout_s
  port="$(svc_port "$svc")"; timeout_s="$(svc_timeout "$svc")"
  if port_open "$port"; then
    echo "  [$svc] already up (port $port open) — skipping"
    return 0
  fi
  echo "  [$svc] docker compose up -d $svc"
  if ! compose up -d "$svc"; then
    echo "  [$svc] docker compose failed" >&2
    return 1
  fi
  if wait_for_port "$port" "$timeout_s"; then
    echo "  [$svc] up — listening on :$port"
  else
    echo "  [$svc] container started but port :$port not open after ${timeout_s}s" >&2
    return 1
  fi
}

docker_stop() {
  local svc="$1"
  echo "  [$svc] docker compose stop $svc"
  compose stop "$svc"
}

# --- process services (npm/ng background jobs) -----------------------------

process_start() {
  local svc="$1" dir port timeout_s cmd pidfile logfile pid
  dir="$(svc_dir "$svc")"; port="$(svc_port "$svc")"; timeout_s="$(svc_timeout "$svc")"
  cmd="$(svc_cmd "$svc")"; pidfile="$PID_DIR/$svc.pid"; logfile="$LOG_DIR/$svc.log"

  if port_open "$port"; then
    echo "  [$svc] already up (port $port open) — skipping"
    return 0
  fi

  if [ ! -d "$dir/node_modules" ]; then
    echo "  [$svc] node_modules missing in $dir — running npm ci (logged to $logfile)..."
    if ! ( cd "$dir" && npm ci ) >"$logfile" 2>&1; then
      echo "  [$svc] npm ci failed — see $logfile" >&2
      return 1
    fi
  fi

  echo "  [$svc] starting: $cmd (cwd: $dir)"
  ( cd "$dir" && exec $cmd ) >"$logfile" 2>&1 &
  pid=$!
  echo "$pid" > "$pidfile"
  disown "$pid" 2>/dev/null || true

  if wait_for_port "$port" "$timeout_s"; then
    echo "  [$svc] up — listening on :$port (pid $pid, log: $logfile)"
  else
    echo "  [$svc] started (pid $pid) but port :$port not open after ${timeout_s}s — check $logfile" >&2
    return 1
  fi
}

process_stop() {
  local svc="$1" port pidfile pid holders
  port="$(svc_port "$svc")"; pidfile="$PID_DIR/$svc.pid"

  if [ -f "$pidfile" ]; then
    pid="$(cat "$pidfile")"
    pid_alive "$pid" && kill "$pid" 2>/dev/null
    rm -f "$pidfile"
  fi

  # PID-based kill is best-effort only (npm/ng often re-exec into a child process) —
  # the port is the reliable target since it names whoever actually bound it.
  if command -v lsof >/dev/null 2>&1; then
    holders="$(lsof -ti "tcp:$port" 2>/dev/null || true)"
    if [ -n "$holders" ]; then
      echo "$holders" | xargs kill 2>/dev/null || true
      sleep 1
      holders="$(lsof -ti "tcp:$port" 2>/dev/null || true)"
      [ -n "$holders" ] && echo "$holders" | xargs kill -9 2>/dev/null || true
    fi
  fi

  if port_open "$port"; then
    echo "  [$svc] warning: port $port still open after stop — check for a leftover process" >&2
  else
    echo "  [$svc] stopped"
  fi
}

# --- status --------------------------------------------------------------------

service_status() {
  local svc="$1" kind port state open="down" note pidnote=""
  kind="$(svc_kind "$svc")"; port="$(svc_port "$svc")"; note="$(svc_note "$svc")"
  port_open "$port" && open="up"

  if [ "$kind" = process ]; then
    local pidfile="$PID_DIR/$svc.pid"
    if [ -f "$pidfile" ]; then
      local pid; pid="$(cat "$pidfile")"
      pid_alive "$pid" || pidnote=" [stale pidfile: $pid]"
    fi
  fi

  printf "  %-9s %-6s port:%-6s %s%s\n" "$svc" "$open" "$port" "$note" "$pidnote"
}

# --- dispatch --------------------------------------------------------------------

usage() {
  cat >&2 <<EOF
Usage: sandbox.sh --start|--stop <service ... | all>
       sandbox.sh --status [service ...]
       sandbox.sh --logs <service> [-f]

Services: $SERVICES
(postgres is status-only — this script never starts/stops it; it's assumed to be your own
native install, per the workspace's existing convention for this repo pair)
EOF
}

ACTION="${1:-}"
[ $# -gt 0 ] && shift

case "$ACTION" in
  --start|--stop)
    if [ $# -eq 0 ]; then usage; exit 2; fi
    if [ "$1" = all ]; then
      # shellcheck disable=SC2206
      ARGS=($SERVICES)
    else
      ARGS=("$@")
    fi
    for svc in "${ARGS[@]}"; do
      if ! is_known_service "$svc"; then
        echo "Unknown service: $svc" >&2
        usage
        exit 2
      fi
    done
    STATUS=0
    if [ "$ACTION" = --start ]; then
      # Cascade: union of every requested service plus its flattened deps, then walk
      # CASCADE_ORDER so dependencies always start before whatever needed them. postgres never
      # appears here (absent from CASCADE_ORDER) even if pulled in via svc_deps.
      CLOSURE=" "
      for svc in "${ARGS[@]}"; do
        CLOSURE="$CLOSURE $svc $(svc_deps "$svc") "
      done
      for svc in "${ARGS[@]}"; do
        [ "$svc" = postgres ] && echo "  [postgres] native install — not managed by this script; start/stop it yourself"
      done
      for svc in $CASCADE_ORDER; do
        case "$CLOSURE" in *" $svc "*)
          warn_missing_deps "$svc"
          if [ "$(svc_kind "$svc")" = docker ]; then docker_start "$svc" || STATUS=1
          else process_start "$svc" || STATUS=1
          fi
        ;; esac
      done
    else
      # --stop never cascades: stopping ui shouldn't tear down shared mongo/redis underneath it.
      for svc in "${ARGS[@]}"; do
        if [ "$svc" = postgres ]; then
          echo "  [postgres] native install — not managed by this script; start/stop it yourself"
          continue
        fi
        if [ "$(svc_kind "$svc")" = docker ]; then docker_stop "$svc" || STATUS=1
        else process_stop "$svc" || STATUS=1
        fi
      done
    fi
    exit "$STATUS"
    ;;
  --status)
    if [ $# -eq 0 ]; then
      # shellcheck disable=SC2206
      ARGS=($SERVICES)
    else
      ARGS=("$@")
      for svc in "${ARGS[@]}"; do
        if ! is_known_service "$svc"; then
          echo "Unknown service: $svc" >&2
          usage
          exit 2
        fi
      done
    fi
    printf "  %-9s %-6s %-11s %s\n" SERVICE STATE PORT NOTES
    for svc in "${ARGS[@]}"; do service_status "$svc"; done
    ;;
  --logs)
    svc="${1:-}"
    if [ -z "$svc" ] || ! is_known_service "$svc"; then usage; exit 2; fi
    logfile="$LOG_DIR/$svc.log"
    [ -f "$logfile" ] || { echo "No log file yet for $svc ($logfile)" >&2; exit 1; }
    if [ "${2:-}" = "-f" ]; then tail -f "$logfile"; else tail -n 60 "$logfile"; fi
    ;;
  -h|--help|*)
    usage
    exit 2
    ;;
esac
