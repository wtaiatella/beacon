---
name: bcs-sandbox
description: "Local multi-service environment lifecycle for the br-tax-engine + br-tax-ui repo pair: start/stop/inspect each datastore and app process individually (mongo, redis, engine, mock, swagger/pecten, ui-proxy, ui) via scripts/tools/sandbox.sh, so /bcs-repro and manual Postman/Swagger/UI testing always run against an already-standing environment instead of re-deriving the local-dev recipe each time. Auto-detects the workspace folder (e.g. bcs, bcs1, bcs2...) to give each simultaneous ticket its own engine/mock/swagger/ui-proxy/ui port range and Mongo DB name (bcs never uses bare :3000/:3888 — those stay free for Next.js and npm test), with zero edits to tracked files inside br-tax-engine/br-tax-ui beyond mock-servers.js honoring SERVER_PORT. Standalone — not wired into the required /run orchestrator."
---

# Sandbox

Stand up and tear down the local dev environment shared by **br-tax-engine** and **br-tax-ui**,
one service at a time, so a human (or `/bcs-repro`) can freely combine whichever subset a scenario
needs — engine + Swagger, engine + Postman, engine + UI, or UI alone — without restarting anything
that's already running and without re-discovering docker-compose/npm-script details from scratch
every session.

**Division of responsibility:** this skill manages raw infra (containers + long-running processes)
plus one generic, mechanical exception — `--seed` (below), which loads the standard citation/
company fixture set with the right per-workspace `DB_NAME` injected. It does **not** decide *what*
ticket-specific data to seed or simulate a ticket's scenario — that is `/bcs-repro`'s job, which
assumes the environment this skill stands up (and `--seed` populates with the generic fixture set)
is already up and just feeds it the specific data/requests a ticket describes. This line moved on
2026-08-06: `--seed` was originally going to live entirely in `/bcs-repro`, but only `/bcs-sandbox` knows
the per-workspace `DB_NAME` mapping (see Multi-workspace below), so duplicating that derivation in
`/bcs-repro` would just be two sources of truth for the same fact.

**`--seed` deliberately does not call `br-tax-engine`'s `seed:local-db` npm script or
`test/_tools/seed-local-db.js`** (revised 2026-08-06, same day it was first built) — that script is
the user's own personal addition, unused by the rest of the team, and expected to be deleted or
rewritten in a future ticket; coupling to it would mean `--seed` breaks whenever that happens.
`scripts/tools/sandbox-seed.js` (new, committed here) is a small, self-contained CLI that this repo
owns instead — it calls `test/_database/index.js` **directly**. That module (not
`seed-local-db.js`) holds the real fixture-loading logic and is genuine, stable, team-owned test
infrastructure (it mirrors what the integration tests' own `before` hooks do) — not something
slated for removal, and not something worth reimplementing independently (it's 600+ lines of
citation/company/tax-rule loading that's already correct). So `--seed` is independent of the one
volatile file, while still relying on the one piece that is not going away.

## Services

All service metadata (dir, port, start command, health-check timeout) lives in one table inside
`scripts/tools/sandbox.sh` — read it there before changing behavior, don't duplicate it here.

| Service | Kind | Port | Origin | Depends on (flattened) | Notes |
|---|---|---|---|---|---|
| `mongo` | docker | 27017 | engine (always) | — | from **br-tax-engine's** `docker-compose.yml` only |
| `redis` | docker | 6379 | engine (always) | — | same compose file as `mongo` |
| `postgres` | native | 5432 | neither (your own native install) | — | **status-only** — never started/stopped by this tool (see Guardrails) |
| `engine` | process | 3000 + offset | engine (always) | mongo, redis, mock, postgres | `npm start` in `br-tax-engine/` |
| `mock` | process | 3888 + offset | engine (always) | — | `npm run mock:server` in `br-tax-engine/` — needed for any `/v3/*` auth call. Bare **:3888** is reserved for `npm test` / `test:services` |
| `swagger` | process | 8000 + offset | engine (always) | engine, mongo, redis, mock, postgres | `npm start` in `br-tax-engine/pecten/` — regenerates the OpenAPI JSON from YAML models, then serves the Swagger UI |
| `ui-proxy` | process | 4000 + offset | ui (always) | engine, mongo, redis, mock, postgres | `npm run proxy:start` in `br-tax-ui/` — forwards to `$ENGINE_URL` (this workspace's engine) |
| `ui` | process | 4200 + offset | ui (always) | ui-proxy, engine, mongo, redis, mock, postgres | `npm start` in `br-tax-ui/` — Angular dev server, proxies via `proxy.conf.json` to `ui-proxy` |

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

## Trigger & Input

- **Trigger:** `/bcs-sandbox …` — arrives as `$ARGUMENTS`.
- **Expected:** flags/service names starting with `--start`, `--stop`, `--status`, `--logs`, or
  `--seed`.
- If `$ARGUMENTS` is empty or does not start with one of those flags, show usage (run the script
  with no args — it prints it) and ask what the user wants, rather than guessing a scenario.

## Invocation (slash / main session)

1. Follow this skill as authoritative (thin utility — not a persona subagent).
2. Run:

   ```bash
   scripts/tools/sandbox.sh $ARGUMENTS
   ```

3. Relay its output plainly — service-by-service start/stop/status lines, and any warning (e.g. a
   port still open after `--stop`, or a health-check timeout after `--start`).
4. On a health-check timeout after `--start <service>`, point the user at
   `scripts/tools/sandbox.sh --logs <service>` before suggesting anything else.
5. Never pass `postgres` to `--start`/`--stop` yourself — the script already refuses it (native
   install, status-only); do not try to start/stop it another way.

## Usage

```bash
scripts/tools/sandbox.sh --start <service ... | all>
scripts/tools/sandbox.sh --stop  <service ... | all>
scripts/tools/sandbox.sh --status [service ...]      # no args = all
scripts/tools/sandbox.sh --logs  <service> [-f]
scripts/tools/sandbox.sh --seed  [--version <2|3|all>] [--goods|--no-goods] [--services|--no-services] [--invoice]
```

`--seed` runs `scripts/tools/sandbox-seed.js` (owned by this repo, not `br-tax-engine`'s
`test/_tools/seed-local-db.js` — see Division of responsibility above for why), resolving and
injecting `DB_NAME` for this workspace's `engine` first (see Multi-workspace below for why a plain
env var isn't enough here). Doesn't require `engine` itself to be running — it connects to Mongo
directly — only `mongo` needs to be up.

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

## Multi-workspace (simultaneous tickets, one workspace folder each)

Added 2026-08-06 after the workspace's actual usage pattern: several sibling folders (e.g. `bcs`,
`bcs1`, `bcs2`, `bcs3`), each its own full clone of `aw1` + `br-tax-engine` + `br-tax-ui`, one
ticket in progress per folder, each needing its own `engine`/`mock`/`swagger`/`ui-proxy`/`ui` —
because those hold the actual ticket branch code (or must not steal the test-reserved mock port),
unlike `mongo`/`redis`/`postgres` which stay shared (see the Services table's Origin column).

**Fully automatic — no new flag.** `WORKSPACE_NAME` is `basename "$ROOT"` (the workspace folder
itself); `WORKSPACE_ID` parses a trailing number and **always starts at 1** (`bcs`→1, `bcs1`→2,
`bcs2`→3, `bcs3`→4; any other folder name hashes to a stable 1–49 via `cksum`, never 0).
`PORT_OFFSET = WORKSPACE_ID * 10000`, added to `engine`(3000)/`mock`(3888)/`swagger`(8000)/
`ui-proxy`(4000)/`ui`(4200). Every `--start`/`--stop`/`--status` prints
`Workspace: <name> (... port offset: +N; npm-test mock stays :3888)` up front so it's always
visible which range is active.

**Why ID never 0 (revised 2026-08-26):** offset 0 kept `bcs` on engine `:3000` (Next.js default —
collides with parallel Next apps) and mock `:3888` (hardcoded by `npm test` / `test:services`).
Starting the sandbox mock on `:3888` made `test:services` fail to bind. Mapping `bcs`→1 pushes
that workspace to `+10000` (`engine:13000`, `mock:13888`, …). Bare `:3888` stays free for the
product suite's own short-lived mock.

**Example ports (after 2026-08-26 mapping):**

| Workspace | ID | Offset | engine | mock | ui-proxy | ui | swagger |
|---|---|---|---|---|---|---|---|
| `bcs` | 1 | +10000 | 13000 | 13888 | 14000 | 14200 | 18000 |
| `bcs1` | 2 | +20000 | 23000 | 23888 | 24000 | 24200 | 28000 |
| `bcs2` | 3 | +30000 | 33000 | 33888 | 34000 | 34200 | 38000 |

**Mock is per-workspace (revised 2026-08-26)** — previously shared on `:3888`. Sandbox starts mock
with `SERVER_PORT=<3888+offset>`; `test/_tools/mock-servers.js` honors that env var and defaults
to `3888` when unset (so `npm test` is unchanged). Engine's `app.config.js` hardcodes every
external mock URL to `:3888`; `svc_env_overrides` rewrites those URLs to this workspace's mock
port via the same `sandbox-pm2-override.js` path used for `SRV_PORT`/`DB_NAME`.

**Sandbox UI authentication uses the fixture's valid compact JWE.** The OAuth mock's password-flow
`default` fixture is a legacy opaque token that the current engine rejects with
`ERR_JWE_INVALID`. `scripts/tools/sandbox-mock-override.js`, loaded only by the sandbox mock via
`NODE_OPTIONS`, replaces that fallback in Node's module cache with the existing `token_unlimited`
JWE before the OAuth router loads. Product tests remain unchanged because they do not load this
preload script.

**Step revised earlier to `*10000` — the `*100` step had a real, confirmed cross-workspace
collision, not a hypothetical one.** All service base ports are multiples of 100, and `ui`
(4200) minus `ui-proxy` (4000) is exactly 200 — two `*100` steps. That means workspace N's `ui` and
workspace N+2's `ui-proxy` always land on the *identical* absolute port. This actually happened in
production use on 2026-08-06: a `/bcs-repro` run in `bcs1` (offset would've been +100 under the old
step) trusted `--status`'s "already up" label for port 4300, which turned out to be **`bcs3`'s own
`ui-proxy`** (offset +300 under the old step), not `bcs1`'s `ui` at all — caught only because that
session independently re-verified port ownership via `lsof`+`ps`+`cwd` walking. `*10000` (bigger
than the full 5000-wide spread from `engine`'s 3000 to `swagger`'s 8000) makes every workspace's
entire service range a self-contained block that cannot overlap any other workspace's range, for
any service, at any workspace-ID distance — this class of collision is now structurally impossible,
not just less likely.

**Don't scan ports/processes machine-wide to check what's running — user-reported real
confusion, not hypothetical.** Several sibling workspaces can have their own `engine`/`swagger`/
`ui-proxy`/`ui` up at once, each on a different offset. A raw `lsof -i`/`ps aux`/`docker ps` scan
shows all of them mixed together with no indication of which belongs to which workspace, and has
already led an assistant to misread the environment. `--status` is the one command that's already
scoped and labeled correctly for the current workspace — prefer it over ad hoc process/port
inspection whenever inspecting this environment, from any tool or session.

**Mongo stays one shared server, but each workspace gets its own DB name** — `svc_db_name`:
`engine` → `brTest_<workspace>`, `ui-proxy` → `AvaTaxBrazil_<workspace>` (each keeps its own
pre-existing bare default as the prefix; that mismatch between the two predates this feature).
Confirmed via `docker exec <mongo-container> mongosh --eval "db.adminCommand('listDatabases')"`
that `brTest_bcs3` gets created alongside the original bare `brTest`, so simultaneous tickets don't
overwrite each other's seeded data even though they share one Mongo process. **Postgres is not
included in this isolation** — it stays one shared native database across every workspace (v1
scope; creating per-workspace Postgres databases would mean this tool creating databases against
the user's own native install, a bigger and more invasive step than an env var — revisit only if
a real collision between simultaneous tickets' Postgres data actually happens).

**The hard part: `engine`'s and `ui-proxy`'s own `server/env-setup.js` /
`proxy/utils/env-setup.js` unconditionally overwrite `process.env` from `pm2.config.js` on every
boot** — `Object.assign($env, pm2Cfg, pm2Env, {...})`, and `Object.assign`'s later arguments always
win. So plain `SRV_PORT=3300 npm start` gets silently clobbered right back to `pm2.config.js`'s
hardcoded `3000` — confirmed this by reading both `env-setup.js` files before assuming env vars
alone would work. `scripts/tools/sandbox-pm2-override.js` (new, committed, generic — parameterized
entirely via `SANDBOX_PM2_CONFIG`/`SANDBOX_ENV_OVERRIDES` env vars, not hardcoded to one repo)
fixes this the right way round: loaded via `NODE_OPTIONS="--require <script>"` before the app's own
entry point runs, it `require()`s the target's `pm2.config.js` (populating Node's module cache) and
mutates that *same* exported object's `apps[0].env` in place. `env-setup.js`'s own later
`require('../pm2.config')` returns that identical cached, already-patched object — so its
`Object.assign` merges in the override as if it always belonged there, instead of fighting the
clobber from outside. This means `PM2_HOME`-based bypass (which would've *also* skipped every
other default `pm2.config.js` provides — SQS flags, secrets, queue names, dozens of keys) was
never necessary and would have been strictly worse.

**The same clobber reaches `test/_database/index.js` too, non-obviously — confirmed the hard way.**
It doesn't require `env-setup.js` directly, but its require chain does:
`test/_database` → `require('../_helpers/storage-helper')` → `storage-helper.js`'s own
`require('../../config')` → `config.js:54`'s `require('./server/env-setup')` — same clobber, and
`storage-helper.js` connects to Mongo at **module-require time** (a top-level `connectDB()` call),
so the override has to be in place *before* that require chain even starts. A real `--seed` run on
2026-08-06 landed 302 documents in the shared bare `brTest` instead of `brTest_bcs3` before this
was caught — this was first found while still wrapping `br-tax-engine`'s own (since-replaced)
`seed:local-db` npm script, where plain `DB_NAME=brTest_bcs3 npm run seed:local-db` looked like it
should work and silently didn't; the same clobber applies identically now that `--seed` calls
`test/_database` directly via `sandbox-seed.js`, since the vulnerable require chain is inside
`test/_database` itself, not in the script that used to sit in front of it. Fixed the same way as
`engine`: `--seed` sets `SANDBOX_PM2_CONFIG`/`SANDBOX_ENV_OVERRIDES` and `NODE_OPTIONS` before
invoking `sandbox-seed.js`. **Lesson for next time a new override target shows up:** grep isn't
enough to rule this out — a target file not directly requiring `env-setup.js` doesn't mean its
require chain doesn't reach it transitively; prefer a real document-count check over any single log
line when in doubt (one log line here is a hardcoded literal unrelated to the real DB; a different
one dynamically reflects the real target and was the actual evidence used to catch this).

**`swagger` and `ui` don't have this problem** — they're plain `ng serve` (Angular CLI directly
reads a `--port` flag, no custom env-merge wrapper), appended via `npm start -- --port N` (npm
forwards trailing args to the script it runs). `ui` additionally needs its proxy target rewritten
to this workspace's own `ui-proxy` port — `br-tax-ui/proxy.conf.json` hardcodes that target inline
(not env-driven), so `process_start` generates a workspace-scoped copy
(`.sandbox/proxy.<workspace>.json`) instead of touching the tracked file, and passes it via
`--proxy-config`. Confirmed via `git status`/`git diff` after a real run: `br-tax-ui/proxy.conf.json`
shows zero diff.

**Net result:** runtime overrides still go through env vars / `NODE_OPTIONS`-loaded scripts /
generated files under `.sandbox/` — no per-ticket edits inside the child repos. The one lasting
child-repo change is `br-tax-engine/test/_tools/mock-servers.js` honoring `SERVER_PORT` (defaults
to `3888` when unset so `npm test` is unchanged). Lifecycle logic lives in `aw1` —
`scripts/tools/sandbox.sh` and `scripts/tools/sandbox-pm2-override.js` — committed once and shared
to every sibling workspace folder by an ordinary `git pull`.

## State

Runtime state lives in `.sandbox/` at the workspace root (gitignored by the workspace's default
`*` rule — not explicitly whitelisted, so no `.gitignore` change was needed):

- `.sandbox/pids/<service>.pid` — best-effort PID tracking for process-kind services
- `.sandbox/logs/<service>.log` — stdout+stderr of each process-kind service, plus any `npm ci` run

`--stop` kills by **port** (via `lsof -ti tcp:<port>`), not just the stored PID — `npm`/`ng`
frequently re-exec into a child process, so the PID file alone isn't a reliable kill target. The
port is always the reliable one, since it names whoever actually bound it.

## Known gotchas (confirmed by a real run, not hypothetical)

- **Node 20 from workspace-root `.nvmrc`** — confirmed 2026-09-18 in `bcs1`. Agent/Cursor shells
  often ship Node 24 while the user's interactive terminal (and `br-tax-engine` native modules
  such as `node-expat`) are Node 20. `.nvmrc` lives at the **workspace root**, not inside
  `br-tax-engine/` or `br-tax-ui/`, so `cd <child-repo> && npm start` never loads it.
  `sandbox.sh` now runs `sandbox_use_node` (nvm + PATH prepend of `$ROOT/.nvmrc`, fallback 20)
  before every Node process (`engine`/`mock`/`ui-proxy`/`ui`/`swagger` and `--seed`) and refuses
  those starts if the resolved `node -v` is not major 20. Do not copy `.nvmrc` into the child
  repos to “fix” this.
- **`mock` must start before/with `engine`, not after** — starting engine first races a scheduled
  `hoplias:schedules:portal-reader` job against `mock` (sandbox port `3888 + offset`) not being
  up yet, producing 3 one-time `ECONNREFUSED` errors in `engine.log`. Validated 2026-08-06 with
  a literal `--start engine mock`. Non-fatal (engine still finished booting, `/v3/token` worked
  once both were up), but avoidable — this is exactly why `CASCADE_ORDER` puts `mock` before
  `engine`: since `--start` now ignores the literal argument order and always walks
  `CASCADE_ORDER` instead, this race is structurally prevented today, not just avoided by
  remembering the right argument order.
- **`engine` and `ui-proxy` both hardcode a Prometheus metrics server on port 8091** (`engine`'s
  `tarrafa:core:common:prometheus-server`; `br-tax-ui/proxy/utils/prometheus-server.js:29`).
  Validated 2026-08-06: with `engine` already up, starting `ui-proxy` logs an `uncaughtException:
  listen EADDRINUSE :::8091` — harmless, non-fatal. `ui-proxy`'s own Express server on :4000 still
  comes up right after and works normally (confirmed end-to-end via `/v3/token` through the
  proxy); only `ui-proxy`'s metrics endpoint silently fails to bind when both run together.

## Guardrails

- **Never start/stop `postgres`.** This repo pair's developers commonly run Postgres natively (per
  `.agents/agents/bcs-repro.md`'s own existing gotcha) — `--start`/`--stop postgres` refuses and tells
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
