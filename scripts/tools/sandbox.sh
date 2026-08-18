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
PM2_OVERRIDE_SCRIPT="$ROOT/scripts/tools/sandbox-pm2-override.js"
SERVICES="mongo redis postgres engine mock swagger ui-proxy ui"

# Multi-workspace support: running this same repo pair cloned into several sibling workspace
# folders (e.g. bcs, bcs1, bcs2, bcs3) needs its own engine/swagger/ui-proxy/ui, one per ticket in
# progress, without editing any file inside br-tax-engine/br-tax-ui (tracked or not). Derived
# automatically from the workspace folder's own name — no extra flag needed. mongo/redis/mock/
# postgres stay shared/unoffset on purpose (see the Services table in SKILL.md).
WORKSPACE_NAME="$(basename "$ROOT")"
if [[ "$WORKSPACE_NAME" =~ ^bcs([0-9]*)$ ]]; then
  WORKSPACE_ID="${BASH_REMATCH[1]:-0}"
else
  WORKSPACE_ID=$(( $(printf '%s' "$WORKSPACE_NAME" | cksum | cut -d' ' -f1) % 50 ))
fi
# Step must exceed the full spread between the lowest and highest service base port (engine 3000
# to swagger 8000 = 5000), otherwise two workspaces N apart can land the SAME absolute port for
# two DIFFERENT services -- confirmed for real on 2026-08-06 with the old *100 step: workspace N's
# ui (base 4200) landed on the identical port as workspace N+2's ui-proxy (base 4000), since both
# base ports are multiples of 100 and differ by exactly 200 (2 steps). *10000 makes every
# workspace's whole 4-service range a self-contained block that can never overlap another
# workspace's, for any service, at any workspace-ID distance.
PORT_OFFSET=$(( WORKSPACE_ID * 10000 ))

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

# mongo/redis/postgres/mock are shared across workspaces (unoffset, same port always) — mock
# mocks external SEFAZ/AWS endpoints only, it holds no ticket-specific code, so one instance can
# safely serve every workspace's engine. engine/swagger/ui-proxy/ui hold the actual ticket branch
# code, so each workspace gets its own via PORT_OFFSET.
svc_port() { case "$1" in
  mongo) echo 27017 ;;
  redis) echo 6379 ;;
  postgres) echo 5432 ;;
  mock) echo 3888 ;;
  engine) echo $(( 3000 + PORT_OFFSET )) ;;
  swagger) echo $(( 8000 + PORT_OFFSET )) ;;
  ui-proxy) echo $(( 4000 + PORT_OFFSET )) ;;
  ui) echo $(( 4200 + PORT_OFFSET )) ;;
esac; }

# Per-workspace Mongo DB name, so simultaneous tickets don't share/clobber each other's seeded
# data even though they share one Mongo *server*. Each keeps its own existing bare default as the
# prefix (engine defaults to brTest, ui-proxy's own session/portal store defaults to AvaTaxBrazil
# — that mismatch predates this script, not something introduced here).
svc_db_name() { case "$1" in
  engine) echo "brTest_${WORKSPACE_NAME}" ;;
  ui-proxy) echo "AvaTaxBrazil_${WORKSPACE_NAME}" ;;
esac; }

# br-tax-engine migrated off PM2 to app.config.js (AVT-71070); ui-proxy still uses pm2.config.js.
svc_pm2_config() { case "$1" in
  engine) echo "$ENGINE_DIR/app.config.js" ;;
  ui-proxy) echo "$UI_DIR/pm2.config.js" ;;
esac; }

# engine's and ui-proxy's own env-setup.js unconditionally overwrites process.env from
# pm2.config.js on every boot (Object.assign($env, pm2Cfg, pm2Env, {...}) — later args win), so
# plain `SRV_PORT=... npm start` gets silently clobbered back to pm2.config.js's hardcoded value.
# sandbox-pm2-override.js (loaded via NODE_OPTIONS, see process_start) patches pm2.config.js's own
# *exported* env object before that Object.assign runs, so the merge picks up these values
# instead of fighting it — zero edits to any file inside br-tax-engine/br-tax-ui, tracked or not.
svc_env_overrides() { case "$1" in
  engine) printf '{"SRV_PORT":"%s","DB_NAME":"%s"}' "$(svc_port engine)" "$(svc_db_name engine)" ;;
  ui-proxy) printf '{"SRV_PORT":"%s","DB_NAME":"%s","ENGINE_URL":"http://localhost:%s"}' \
    "$(svc_port ui-proxy)" "$(svc_db_name ui-proxy)" "$(svc_port engine)" ;;
  *) echo "" ;;
esac; }

svc_dir() { case "$1" in
  engine|mock) echo "$ENGINE_DIR" ;;
  swagger) echo "$ENGINE_DIR/pecten" ;;
  ui-proxy|ui) echo "$UI_DIR" ;;
esac; }

# swagger/ui are plain `ng serve` under the hood (no pm2.config.js clobber issue) — Angular CLI
# accepts --port directly, appended via `npm start -- ...` (npm forwards trailing args to the
# script it runs). ui also needs its own proxy target rewritten to this workspace's ui-proxy port
# — proxy.conf.json hardcodes the target inline (not env-driven), so process_start generates a
# workspace-specific copy under .sandbox/ instead of touching br-tax-ui's tracked file.
svc_cmd() { case "$1" in
  engine) echo "npm start" ;;
  mock) echo "npm run mock:server" ;;
  swagger) echo "npm start -- --port $(svc_port swagger)" ;;
  ui-proxy) echo "npm run proxy:start" ;;
  ui) echo "npm start -- --port $(svc_port ui) --proxy-config $STATE_DIR/proxy.$WORKSPACE_NAME.json" ;;
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
  ui-proxy) echo "forwards to this workspace's own engine (http://localhost:$(svc_port engine))" ;;
  ui) echo "ng serve, proxies via generated proxy config -> this workspace's ui-proxy (:$(svc_port ui-proxy))" ;;
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
  local svc="$1" dir port timeout_s cmd pidfile logfile pid overrides
  dir="$(svc_dir "$svc")"; port="$(svc_port "$svc")"; timeout_s="$(svc_timeout "$svc")"
  cmd="$(svc_cmd "$svc")"; pidfile="$PID_DIR/$svc.pid"; logfile="$LOG_DIR/$svc.log"
  overrides="$(svc_env_overrides "$svc")"

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

  if [ "$svc" = ui ]; then
    # proxy.conf.json hardcodes its target inline (not env-driven) — generate a workspace-scoped
    # copy pointed at *this* workspace's ui-proxy port instead of editing br-tax-ui's tracked file.
    sed "s/4000/$(svc_port ui-proxy)/g" "$UI_DIR/proxy.conf.json" > "$STATE_DIR/proxy.$WORKSPACE_NAME.json"
  fi

  echo "  [$svc] starting: $cmd (cwd: $dir)"
  if [ -n "$overrides" ]; then
    ( cd "$dir"
      export SANDBOX_PM2_CONFIG="$(svc_pm2_config "$svc")"
      export SANDBOX_ENV_OVERRIDES="$overrides"
      export NODE_OPTIONS="--require $PM2_OVERRIDE_SCRIPT"
      exec $cmd
    ) >"$logfile" 2>&1 &
  else
    ( cd "$dir" && exec $cmd ) >"$logfile" 2>&1 &
  fi
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
       sandbox.sh --seed [--version <2|3|all>] [--goods|--no-goods] [--services|--no-services] [--invoice]

Services: $SERVICES
(postgres is status-only — this script never starts/stops it; it's assumed to be your own
native install, per the workspace's existing convention for this repo pair)
EOF
}

ACTION="${1:-}"
[ $# -gt 0 ] && shift

case "$ACTION" in
  --start|--stop|--status|--seed)
    echo "Workspace: $WORKSPACE_NAME (engine/swagger/ui-proxy/ui port offset: +$PORT_OFFSET)" >&2
    ;;
esac

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
  --seed)
    # Deliberately independent of br-tax-engine's own test/_tools/seed-local-db.js and its
    # `seed:local-db` npm script (a personal, team-unused script the user may delete/rewrite) —
    # scripts/tools/sandbox-seed.js is a small CLI this repo owns that calls test/_database/
    # index.js directly (the actual, team-owned integration-test seeding module; not going away).
    # Injects the DB_NAME this workspace's engine actually reads (see svc_db_name) so seeding
    # can't silently land in the wrong database.
    #
    # Plain `DB_NAME=... node ...` is NOT enough on its own, confirmed the hard way (a real seed
    # run landed in the shared bare `brTest` on 2026-08-06 despite this env var being set):
    # test/_database (require '../_helpers/storage-helper') -> storage-helper.js's own
    # `require('../../config')` -> config.js:54 `require('./server/env-setup')` -> the same
    # Object.assign($env, pm2Cfg, pm2Env, {...}) clobber that engine itself has. storage-helper.js
    # also connects to Mongo at require *time* (module-scope top-level `connectDB()` call), so by
    # the time our env var would've been read, it's already been reset to pm2.config.js's
    # hardcoded 'brTest'. Needs the same NODE_OPTIONS preload engine/ui-proxy use (see
    # svc_env_overrides) for the override to actually stick.
    SEED_DB="$(svc_db_name engine)"
    if ! port_open "$(svc_port mongo)"; then
      echo "  [seed] warning: mongo (port $(svc_port mongo)) not reachable — this will likely fail" >&2
    fi
    if [ ! -d "$ENGINE_DIR/node_modules" ]; then
      echo "  [seed] node_modules missing in $ENGINE_DIR — running npm ci first..."
      ( cd "$ENGINE_DIR" && npm ci ) || { echo "  [seed] npm ci failed" >&2; exit 1; }
    fi
    echo "  [seed] DB_NAME=$SEED_DB node scripts/tools/sandbox-seed.js -- $*"
    (
      cd "$ENGINE_DIR"
      export SANDBOX_PM2_CONFIG="$(svc_pm2_config engine)"
      export SANDBOX_ENV_OVERRIDES="$(printf '{"DB_NAME":"%s"}' "$SEED_DB")"
      export NODE_OPTIONS="--require $PM2_OVERRIDE_SCRIPT"
      node "$ROOT/scripts/tools/sandbox-seed.js" "$ENGINE_DIR" "$@"
    )
    exit $?
    ;;
  -h|--help|*)
    usage
    exit 2
    ;;
esac
