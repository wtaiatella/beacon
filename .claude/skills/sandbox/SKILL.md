---
name: sandbox
description: "Local multi-service environment lifecycle for the br-tax-engine + br-tax-ui repo pair: start/stop/inspect each datastore and app process individually (mongo, redis, engine, mock, swagger/pecten, ui-proxy, ui) via scripts/tools/sandbox.sh, so /repro and manual Postman/Swagger/UI testing always run against an already-standing environment instead of re-deriving the local-dev recipe each time. Standalone — not wired into the required /run orchestrator."
---

# Sandbox

Stand up and tear down the local dev environment shared by **br-tax-engine** and **br-tax-ui**,
one service at a time, so a human (or `/repro`) can freely combine whichever subset a scenario
needs — engine + Swagger, engine + Postman, engine + UI, or UI alone — without restarting anything
that's already running and without re-discovering docker-compose/npm-script details from scratch
every session.

**Division of responsibility:** this skill only manages raw infra (containers + long-running
processes). It does **not** seed data or simulate a ticket's scenario — that is `/repro`'s job,
which assumes the environment this skill stands up is already up and just feeds it the specific
data/requests a ticket describes.

## Services

All service metadata (dir, port, start command, health-check timeout) lives in one table inside
`scripts/tools/sandbox.sh` — read it there before changing behavior, don't duplicate it here.

| Service | Kind | Port | Origin | Depends on (flattened) | Notes |
|---|---|---|---|---|---|
| `mongo` | docker | 27017 | engine (always) | — | from **br-tax-engine's** `docker-compose.yml` only |
| `redis` | docker | 6379 | engine (always) | — | same compose file as `mongo` |
| `postgres` | native | 5432 | neither (your own native install) | — | **status-only** — never started/stopped by this tool (see Guardrails) |
| `engine` | process | 3000 | engine (always) | mongo, redis, mock, postgres | `npm start` in `br-tax-engine/` |
| `mock` | process | 3888 | engine (always) | — | `npm run mock:server` in `br-tax-engine/` — needed for any `/v3/*` auth call |
| `swagger` | process | 8000 | engine (always) | engine, mongo, redis, mock, postgres | `npm start` in `br-tax-engine/pecten/` — regenerates the OpenAPI JSON from YAML models, then serves the Swagger UI |
| `ui-proxy` | process | 4000 | ui (always) | engine, mongo, redis, mock, postgres | `npm run proxy:start` in `br-tax-ui/` — forwards to `$ENGINE_URL` (defaults to `http://localhost:3000`) |
| `ui` | process | 4200 | ui (always) | ui-proxy, engine, mongo, redis, mock, postgres | `npm start` in `br-tax-ui/` — Angular dev server, proxies via `proxy.conf.json` to `ui-proxy` |

**Origin never varies today** — `mongo`/`redis`/`engine`/`mock`/`swagger` always resolve to
`br-tax-engine`, `ui-proxy`/`ui` always resolve to `br-tax-ui`, regardless of which other services
are requested in the same `--start` call. This is deliberate (see "Why only one repo's
mongo/redis" below) — there is currently no scenario where a service's source repo depends on
context, so nothing in the script branches on that.

**`--start` auto-cascades through dependencies; `--stop` never does.** `--start <svc>` walks
`<svc>`'s flattened `svc_deps` in a fixed boot order (`CASCADE_ORDER` in the script: `mongo redis
mock engine ui-proxy swagger ui`) and starts whichever of those aren't already up yet, before
starting `<svc>` itself — so `--start ui` alone is enough to bring up `mock`, `engine`, `ui-proxy`,
and `ui`, in that order, with no separate step. Anything already listening on its port is skipped
(idempotent — safe to re-run). `postgres` is deliberately never part of the cascade (absent from
`CASCADE_ORDER`) even though it's in `svc_deps` — it can't be auto-started, so `svc_deps` is also
still used post-cascade as a `warn_missing_deps` sanity check, which now only ever has something
real to say about `postgres` being down (or a cascade step that failed, e.g. a timeout).
`--stop <svc>` only ever stops `<svc>` itself — stopping `ui` must never tear down the shared
`mongo`/`redis` (or `engine`) other things still depend on. Superseded 2026-08-06 (was
feedback-only warnings with no auto-start) after real usage showed listing every dependency by
hand on every `--start` was pure friction with no upside — see Guardrails.

**Why only one repo's `mongo`/`redis`:** both `br-tax-engine/docker-compose.yml` and
`br-tax-ui/docker-compose.yml` define `mongo`/`redis` on the same host ports (27017/6379).
Bringing up both stacks collides. `br-tax-ui`'s compose also defines its own `engine` and
`mock-server` containers (prebuilt images) — those are **not** used here; when a scenario needs
the real engine, run it from source (the `engine` service above) instead, which also avoids a port
3000 collision with `br-tax-ui`'s dockerized `engine`.

## Usage

```bash
scripts/tools/sandbox.sh --start <service ... | all>
scripts/tools/sandbox.sh --stop  <service ... | all>
scripts/tools/sandbox.sh --status [service ...]      # no args = all
scripts/tools/sandbox.sh --logs  <service> [-f]
```

Composing a scenario is just naming the top-level service it needs — the cascade brings in
everything under it:

- Engine + Postman/Swagger-ready: `--start engine` (brings `mongo`, `redis`, `mock` too)
- Engine + Swagger UI: `--start swagger` (brings `engine` + its own deps too)
- Engine + UI (cross-repo fix): `--start ui` (brings `ui-proxy`, `engine`, `mongo`, `redis`, `mock`)
- UI-only change: same as above — `--start ui` — since UI still needs a real engine behind the
  proxy unless the change is purely client-side and mockable; there is no separate "UI-only"
  service subset today, ask before assuming one isn't needed

Naming individual services still works exactly as before (e.g. `--start mongo` alone, or
`--start engine swagger` together) — the cascade is additive, not a replacement for
service-by-service control.

`--start` on a service already listening on its port is a no-op (reports "already up"). Missing
`node_modules` is installed automatically (`npm ci`) the first time a process-kind service starts.

## State

Runtime state lives in `.sandbox/` at the workspace root (gitignored by the workspace's default
`*` rule — not explicitly whitelisted, so no `.gitignore` change was needed):

- `.sandbox/pids/<service>.pid` — best-effort PID tracking for process-kind services
- `.sandbox/logs/<service>.log` — stdout+stderr of each process-kind service, plus any `npm ci` run

`--stop` kills by **port** (via `lsof -ti tcp:<port>`), not just the stored PID — `npm`/`ng`
frequently re-exec into a child process, so the PID file alone isn't a reliable kill target. The
port is always the reliable one, since it names whoever actually bound it.

## Known gotchas (confirmed by a real run, not hypothetical)

- **`mock` must start before/with `engine`, not after** — starting engine first races a scheduled
  `hoplias:schedules:portal-reader` job against `mock` (port 3888) not being up yet, producing 3
  one-time `ECONNREFUSED` errors in `engine.log`. Validated 2026-08-06 with a literal
  `--start engine mock`. Non-fatal (engine still finished booting, `/v3/token` worked once both
  were up), but avoidable — this is exactly why `CASCADE_ORDER` puts `mock` before `engine`: since
  `--start` now ignores the literal argument order and always walks `CASCADE_ORDER` instead, this
  race is structurally prevented today, not just avoided by remembering the right argument order.
- **`engine` and `ui-proxy` both hardcode a Prometheus metrics server on port 8091** (`engine`'s
  `tarrafa:core:common:prometheus-server`; `br-tax-ui/proxy/utils/prometheus-server.js:29`).
  Validated 2026-08-06: with `engine` already up, starting `ui-proxy` logs an `uncaughtException:
  listen EADDRINUSE :::8091` — harmless, non-fatal. `ui-proxy`'s own Express server on :4000 still
  comes up right after and works normally (confirmed end-to-end via `/v3/token` through the
  proxy); only `ui-proxy`'s metrics endpoint silently fails to bind when both run together.

## Guardrails

- **Never start/stop `postgres`.** This repo pair's developers commonly run Postgres natively (per
  `.claude/agents/repro.md`'s own existing gotcha) — `--start`/`--stop postgres` refuses and tells
  the user to manage it themselves; `--status postgres` only checks port 5432 reachability.
- **Never bring up `br-tax-ui`'s own `docker-compose.yml`** for `mongo`/`redis` — always use
  `br-tax-engine`'s, to avoid the port collision described above.
- **`--start` cascades through `svc_deps` via `CASCADE_ORDER`; `--stop` never cascades.** This was
  revisited on purpose (see the Services section above) — don't re-add per-dependency `--start`
  listing as a requirement, and don't make `--stop` cascade either (it must never take down shared
  infra another running service still needs).
- Local only — this manages developer-machine processes/containers, never a remote environment.
- Don't invent scenario *names* as new script flags (no `--scenario ui-only`) — keep every service
  individually addressable by name (cascade or not) so a new combination is just a different
  `--start` argument list, never a code change.
