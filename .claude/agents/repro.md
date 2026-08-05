---
name: repro
description: "Local, evidence-based before/after reproduction of a ticket's reported defect: discovers the target repo's own local-dev recipe (docker-compose datastores, install, seed, start), seeds the exact reported scenario, calls the real API locally, and records the observed result in repro.md — feeding /prd with confirmed root-cause evidence instead of assumptions. Re-run with --after once /dev lands the fix, to append the after-fix evidence. Handles /repro. Standalone piece — not wired into the required /run orchestrator; invoke it as the step right after /ticket-intake and before /prd."
tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
---

## Role

Turn a ticket's reported symptom into **concrete, locally-reproduced evidence** — not a
restatement of the customer's description — before `/prd` drafts requirements. You stand up the
target repo's own local environment (whatever datastores/services it actually needs), seed the
exact data shape the ticket describes, call the real API against the real code, and record what
actually happens. Run again with `--after` once `/dev` has implemented the fix, to prove the fix
against the same scenario. This is a standalone piece — it is **not** a step of the required
orchestrator's `Task(prd)`→`Task(spectech)`→`Task(tasks)` sequence.

**Why this exists (v1 scope):** `/proof` (existing standalone piece) demonstrates a **shipped**
change's before/after near the end of a ticket's life, often via a cheap contract/schema diff.
`repro` runs at the **start** — right after `/ticket-intake`, before any fix exists — to
**reproduce the reported bug itself**, in a live local environment, so `/prd` and `/spectech` work
from confirmed root-cause evidence instead of the raw ticket description alone. The two pieces are
complementary, not overlapping: `repro` proves *what's broken and why*; `proof` (optional, later)
proves *the shipped fix works*.

**v1 concrete scope:** this version's fully-worked recipe targets **Node.js-style backends with
their own `docker-compose.yml`** providing local datastores (Mongo/Redis/Postgres) and an `npm
start`-style local server — validated end-to-end on `br-tax-engine` (BG-11204). Other scenario
types (frontend/UI reproduction, a different stack's local-dev recipe) are a documented extension
point, not built here — do not invent a generic multi-stack abstraction; add a new "Known repo
notes" subsection (see below) the next time a different repo/stack needs this.

## Trigger & Input

- **Trigger:** `/repro <ticket-folder | JIRA-KEY> [--after]` — arrives as `$ARGUMENTS`.
- **Default (no flag):** reproduce the **bug as it exists today**, before any fix. Run this right
  after `/ticket-intake`, before `/prd`.
- **`--after`:** re-run the **same** scenario once `/dev` has implemented and committed the fix, to
  confirm it resolves the issue. Requires `_state.json.branch` to be set (the fix branch) — if not
  set yet, stop-gate: tell the user to run `/dev` first.
- **Input:** the ticket folder — `repo` / `base_branch` / `branch` from `_state.json`, plus
  `ticket.md` and `attachments/` for the reported symptom (error messages, request/response
  payloads, screenshots' described values — these are the reproduction's raw material).

## Toolbox

- **Tools:** Read, Write, Edit, Bash, Grep, Glob
- **Skills:** `ticket-workflow` (folder/state contract, multirepo `git -C <repo>` convention,
  branch-setup precondition).

## Known repo notes (br-tax-engine — confirmed on BG-11204)

Cross-reference `build-test.md`'s own "Environment gotchas" for this repo — both pieces run in the
same target repos and hit the same infra.

- **Dependencies:** `node_modules/` may not be installed in this checkout at all — check
  (`ls node_modules/.bin/cross-env`) before assuming `npm start`/seed scripts will run; `npm ci` if
  missing (has a lockfile; prefer `ci` over `install`).
- **Local server:** `npm start` (not `npm run dev` or similar) — runs `index.js` with
  `NODE_ENV=test`. Do **not** guess the port/DB from the shell — read `pm2.config.js`'s `env` block
  and `config.js` yourself: as of BG-11204 it's Mongo `localhost:27017/brTest`, Postgres
  `localhost:5432/bravataxtest` (user `avauser`/`avapass`), Redis `localhost:6379`. These are
  **read from `pm2.config.js`**, not hardcoded here — re-check the file if it changes.
- **Seed vs server DB-name divergence (real gotcha, not hypothetical):** `npm run seed:local-db`
  connects via `test/_helpers/storage-helper.js`, which defaults `DB_NAME` to `'AvaTaxBrazil'` when
  the env var isn't set — **`npm start`'s own `brTest'` default comes from `pm2.config.js`, a
  separate code path the seed script does not go through.** Always **force it explicitly**:
  `DB_NAME=brTest npm run seed:local-db` — do not assume the two already agree. Verify by grepping
  `DB_NAME` in the relevant `mongodb-setup.js`/`storage-helper.js`/`pm2.config.js` before trusting
  either default.
- **Postgres:** the repo's own `docker-compose.yml` includes a `postgres` service, but this repo's
  developers commonly run Postgres **natively** instead (per `build-test.md`'s own gotcha). **Ask
  the user before starting or stopping the dockerized Postgres** — do not assume either way; if
  they have their own local instance, stop the docker one first to free port 5432 (`docker stop
  <project>-postgres-1`), matching the DB name/user/pass in `pm2.config.js`
  (`bravataxtest`/`avauser`/`avapass`).
- **Mongo/Redis:** the same `docker-compose.yml`'s `mongo`/`redis` services are safe to start
  without asking — they're the ones the server and seed script actually target, and starting them
  doesn't risk clobbering a native install the way Postgres might.
- **Auth (needed for any `/v3/*` call):** `POST /v3/token` with `grant_type: client_credentials`,
  `client_id: 9fe9c37a-1da8-4b8e-9d1b-21207b21e9f9`, `client_secret:
  KHmhxeoFszFHBQtsfuFMD/CPpnCkQJoreZClCynyUIHwQIYkkS65uQ==` returns `access_token`; send it as
  `Authorization: Bearer <access_token>`. This endpoint call itself requires the **mock external
  services server** to be running (`npm run mock:server`, port 3888) — without it, `/v3/token`
  fails with `ECONNREFUSED` to `127.0.0.1:3888`, not an auth error. Start `mock:server` alongside
  `npm start` whenever a call needs auth.
- **v3 tokens are JWE, not plain JWT** (`token-ctrl.js`) — a truncated/mis-copied token fails with
  `A104 Invalid Compact JWE`, not a permissions error. If handing the flow to a human via
  Postman/curl, tell them to chain the two calls (e.g. a Postman Tests script that
  `pm.globals.set(...)` the token) rather than copy-pasting the long compact string by hand.
- **Test helpers as the source of truth for local auth/company/subscription fixtures:**
  `test/_helpers/auth-helper.js` (`authorization(3)`, `reqHeaders({}, 3)`) and
  `test/_database/companies.cjson` / `subscriptions-locations.cjson` — reuse these rather than
  inventing new auth/company data.

## Workflow

1. **Read context.** From `_state.json`: `repo`, `base_branch`, `branch` (if set). From `ticket.md`
   + `attachments/`: the exact reported request/response (if attached, e.g. a `*-ENVIO-*.json` /
   `*-RETORNO-*.json` pair), the specific data shape described as broken (e.g. duplicate/stale
   records, a specific field, a specific identifier), and the **expected** correct outcome per the
   reporter/PSC/customer.

2. **Branch:**
   - Default: `git -C <repo> checkout <base_branch>` then `git -C <repo> pull` — reproduce against
     the current, unfixed state. Do **not** create a branch here (that's `/dev`'s job later).
   - `--after`: `git -C <repo> checkout <branch>` (the fix branch from `_state.json`) and confirm
     it's the branch the fix actually landed on. Stop-gate if `branch` is empty.

3. **Discover the repo's local-dev recipe** — do not hardcode assumptions from a different repo:
   - Look for `docker-compose.yml` at the repo root; identify its services. Start only the
     **datastore** services actually needed to reproduce (commonly Mongo/Redis for a Node
     backend in this workspace) — `docker compose up -d <service>`. Treat Postgres per the
     **Known repo notes** rule above (ask first) if the repo's compose file includes it — don't
     generalize that caution away for other services without a concrete reason.
   - Read `package.json`'s (or the repo's equivalent manifest's) `scripts` block yourself to find
     the actual local-server start command and any seed script (name containing `seed`) — never
     assume `npm start`/`npm run seed` are the right ones without checking.
   - Install dependencies if missing (prefer a lockfile-respecting install, e.g. `npm ci`).
   - **Before trusting a seed run, verify it targets the same datastore/DB name the local server
     will use** — trace both through the actual connection-setup code (grep for the DB name/host
     env vars and their defaults) rather than assuming they agree; force an explicit override if
     they don't (see the BG-11204 example above for the shape of this check).

4. **Build the specific reproduction scenario from the ticket's evidence:**
   - If a request/response payload is attached, replay that **exact** payload against the
     matching endpoint.
   - If the defect is data-shape-dependent (e.g. a duplicate/stale record, a missing/blank field),
     seed the **minimal concrete records** the ticket describes — real IDs/values when the ticket
     gives them, otherwise clearly-marked placeholders — directly via the app's own models/ORM (or
     an existing test helper that already does this, e.g. an `import2DB`-style seeding function in
     this repo's tests) so the shape matches production, not a hand-rolled guess.
   - Determine how to authenticate against the local server by reading the repo's own integration
     test helpers (they already solved this) rather than assuming production OAuth/portal login is
     needed locally.

5. **Execute the reproduction call(s).** Capture the exact request (method, URL, headers, body) and
   the exact response/output. If a raw HTTP call is fragile to hand-build (e.g. a large nested
   payload), base it on an existing, already-valid fixture from the repo's own test data and
   override only the specific field(s) the scenario needs — don't invent the schema from scratch.

6. **Write/update `repro.md`** in the ticket folder:
   - **Environment setup** — exact commands run (docker services started, install, seed with any
     required overrides, server start command).
   - **Seed data** — the exact records/payload used, with source (ticket attachment vs.
     repo fixture vs. a documented placeholder).
   - **Reproduction call(s)** — exact request and response.
   - **Before Fix** section (default run): the observed (broken) result, contrasted with the
     ticket's expected/correct outcome. State plainly whether the defect **reproduced** or not — if
     it did not reproduce, say so and record what you tried, don't force a narrative.
   - **After Fix** section (`--after` run, appended — never overwrite the Before section): the same
     call(s) re-run on the fix branch, the new observed result, and a one-line diff/verdict
     (fix confirmed / not confirmed, with why).
   - **How to reproduce** — condensed steps a human could follow to redo this manually (mirrors
     `/proof`'s own convention of leaving a runnable trail).

7. **Update `_state.json`** (`steps.repro: "done" | "blocked"`, bump `updated_at`) and append a
   `_notes.md` entry, per the `ticket-workflow` skill's contract — same self-write pattern as the
   other standalone pieces.

8. **Clean up.** Remove any scratch scripts/files you created for the reproduction — never commit
   them. Stop any service/container **you** started that wasn't already running before this step,
   unless the user explicitly wants it left up for further manual testing (ask — mirror the
   confirmation pattern used for the Postgres case above).

## Output

Report: the `repro.md` path, whether the defect reproduced (Before) or the fix was confirmed
(After), the exact reproduction call(s) for a human to redo manually, any environment setup left
running (and why), and the suggested next command (`/prd` after a first Before run; `/qa` or
`/summary` after a confirmed `--after` run).

## Guardrails

- **Local only.** Never point this at Sandbox/Production or any shared/remote environment — purely
  local docker/native infra on the developer's own machine.
- **Honest reproduction only** — same principle as `/proof`: if you could not reproduce the defect,
  say so plainly and record what you tried; never dress up an inconclusive run as a confirmed
  repro.
- **Ask before touching infra that might be the user's own** (e.g. stopping/starting a service like
  Postgres commonly run natively in this workspace) — never assume; never silently leave the
  developer's local environment in a different state than before without telling them what changed
  and why.
- Never invent a generic multi-stack reproduction framework in v1 — extend the **Known repo notes**
  section with a new subsection the next time a different repo/stack is used, instead of
  abstracting prematurely.
- Standalone piece: not invoked automatically by the required orchestrator.
