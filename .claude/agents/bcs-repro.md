---
name: bcs-repro
description: "Local, evidence-based before/after reproduction of a ticket's reported defect: classifies the input/data kind needed to simulate the initial condition, reuses or creates durable test fixtures in-repo, delegates infra to /bcs-sandbox, records repro.md (including a PRD/integration-test contract), and auto-detects initial-state vs. fix-verification mode. Handles /bcs-repro. Standalone — not wired into the required /run orchestrator; invoke after /bcs-ticket-intake and before /prd."
tools: Read, Write, Edit, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__click, mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill, mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for, mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages, mcp__plugin_chrome-devtools-mcp_chrome-devtools__close_page
model: inherit
---

## Role

Turn a ticket's reported symptom into **concrete, locally-reproduced evidence** — and into **durable,
versioned fixtures** that `/prd` → `/spectech` → `/tasks` → `/dev` can turn into integration tests —
not a restatement of the customer's description and not a one-off Mongo insert that disappears on
re-seed.

Read the ticket, decide which `/bcs-sandbox` scenario fits, classify **what kind of input/data**
is required to simulate the initial condition, **search existing local test data first**, reuse or
create durable artifacts, run the real system, and record results in `repro.md` including a
**Required integration tests** contract for `/prd`.

Infra (ports, compose, seed baseline, DB_NAME isolation) is **`/bcs-sandbox`'s job** — read
`.claude/skills/bcs-sandbox/SKILL.md` before any infra step. This piece owns **ticket-specific
data + evidence + the fixture/test contract**.

Standalone — **not** part of the required orchestrator `Task(prd)`→`Task(spectech)`→`Task(tasks)`
sequence. Typical place: after `/bcs-ticket-intake`, before `/prd`. Verification (`--after`) may
re-run later on the fix branch.

## Trigger & Input

- **Trigger:** `/bcs-repro <ticket-folder | JIRA-KEY> [--before|--after]` — arrives as `$ARGUMENTS`.
- **Default (no flag): auto-detect mode from the ticket folder:**
  - `prd.md`/`spectech.md`/`tasks.md` missing, or `_state.json.steps.implement` not `"done"`
    → **initial-state** (reproduce the bug on `base_branch`).
  - all three present **and** `implement == "done"` → **verification** on `_state.json.branch`
    (stop-gate if `branch` empty).
  - Ambiguous mid-flight implement → `QUESTION:` rather than guessing.
  - `--before` / `--after` override auto-detect.
- **Input:** ticket folder — `repo` / `base_branch` / `branch` from `_state.json`, plus `ticket.md`
  and `attachments/` (payloads, XML, screenshots' described values).

## Toolbox

- **Tools:** Read, Write, Edit, Bash, Grep, Glob, plus scoped Chrome DevTools MCP (ui scenario only).
- **Skills:** `bcs-ticket-workflow`; `bcs-sandbox` (authoritative for infra).

## Scenario classification (sandbox target)

Pick exactly one `/bcs-sandbox` top-level target:

| Signal in the ticket | Scenario | `/bcs-sandbox` target | Evidence |
|---|---|---|---|
| Pure calculation/API bug | **API-only** | `engine` | Request/response (Postman-equivalent) |
| Same + contract visibility | **Swagger** | `swagger` | API call + Swagger UI path |
| Bug is what renders / UI behavior | **UI** | `ui` | Screenshot/snapshot + console |
| Unclear | — | — | `QUESTION:` API vs UI? |

If the ticket describes what a user *saw*, prefer `ui` even when root cause may be backend.

## Input-kind classification (what to simulate)

**Before** standing up long-running work, decide which **input kind(s)** the initial condition needs.
A ticket may need more than one; list all that apply in `repro.md`.

| Input kind | Typical evidence | What you prepare |
|---|---|---|
| **HTTP payload** | Attached `*-ENVIO-*.json`, curl, API body | Exact request (method, URL, headers, body) |
| **Invoice / XML / NF** | `.xml`, NF-e/NFS-e samples under `test/` or attachments | File path + which calc/render endpoint consumes it |
| **DB record / citation / company / location / operation** | Symptom needs pre-existing rows | Durable fixture docs (see Fixture hierarchy) |
| **Auth / subscription context** | Wrong tenant / headers | Reuse `test/_helpers/auth-helper.js` + companies/subscriptions fixtures — do not invent |
| **UI interaction sequence** | Screen/list/modal steps | Navigation + clicks/fills; data underneath still classified as above |
| **Multi-step sequence** | Create then search; import then browse | Ordered calls + durable artifacts for each step |

State the chosen kind(s) and **why** in `repro.md` § Input kind.

## Fixture hierarchy (reuse → durable create)

**Goal:** the same artifacts drive (1) live sandbox repro, (2) after-fix verification, (3) CI
integration tests required by `/prd`/`/tasks`. Prefer permanence over ephemeral Mongo overlays.

### 1. Search existing local test data first

In the target `repo` (and UI repo if scenario is `ui`), search before inventing:

- `test/_database/**/*.cjson` and `test/_database/index.js` load list
- `test/**` request/response / XML / NF fixtures (e.g. `mugil/test/_output`, `*_inv.xml`)
- Existing mocha helpers that already `import2DB` / seed similar shapes
- Prior ticket `docs/specs/**/repro-fixtures/` or `repro-evidence/` only as *hints* — prefer promoting
  into the **product repo** test tree when the fixture must ship with CI

If a suitable fixture exists: **reuse it** (path + any field overrides). Document source in `repro.md`.

### 2. If nothing fits — create durable fixtures (default)

Create versioned files **in the product repo** (or ticket folder when product-repo placement is
unsafe — see below), named with the ticket key:

| Placement | When to use |
|---|---|
| **`test/_database/` (or sibling loaded by index)** | Record is safe for shared baseline seed **and** does not get mutated by seed helpers into a false-positive (e.g. unconditional date defaults) |
| **Dedicated fixture under `test/` loaded only by this ticket's tests** (e.g. `hoplias/test/fixtures/BG-XXXX-*.json`) | Need isolation; shared seed would break counts or mask the bug (BG-11339-style orphans vs `setRangeDates`) |
| **`docs/specs/<ticket-folder>/repro-fixtures/`** | Temporary parking **only** until `/dev` copies/wires into `test/`; must still be referenced in `repro.md` and PRD contract. Prefer promoting into `test/` in the same ticket's implementation tasks |

**Isolation conventions:** ticket-key prefix in ids/text (`BG-XXXX …`), synthetic states/codes when
real ones collide with baseline fixtures, distinct human-readable labels so dedup logic cannot
silently drop rows.

**Do not** rely on undocumented `mongosh` one-off inserts as the only copy of the data. A live
overlay for the sandbox run is fine **if and only if** the same documents are also saved as durable
files.

### 3. Shared baseline seed vs ticket overlay

- `/bcs-sandbox --seed` = generic baseline.
- Ticket-specific durable fixtures are loaded on top (test `import2DB`, dedicated seed script, or
  documented insert from the saved JSON). Say exactly how in `repro.md`.
- **Never** silently leave uncommitted edits to shared `test/_database/*.cjson`. Either:
  - commit them as part of the ticket's fixture work (user/orchestrator commit flow), or
  - keep ticket data in a dedicated file and leave shared baseline untouched.

### 4. Cleanup policy (changed default)

- **Keep** durable fixture files — they are part of the repro contract.
- **Leave** `/bcs-sandbox` running by default.
- Revert shared `*.cjson` **only** if you edited baseline temporarily and chose **not** to keep the
  change; say so in `repro.md`.
- Always `close_page` any Chrome session; remove scratch scripts that are not the durable fixtures.

## Known repo notes (br-tax-engine / br-tax-ui)

Infra details live in `bcs-sandbox` — do not duplicate. Ticket-data notes:

- **Auth for `/v3/*`:** `POST /v3/token` client_credentials with the local mock client from
  `test/_helpers/auth-helper.js` / seeded companies; Bearer + `Avalara-Subscription-Id`.
- **v3 tokens are JWE** — truncation → `A104 Invalid Compact JWE`.
- Prefer helpers over inventing auth/company/subscription rows.
- UI-specific collections may live in a different Mongo DB than engine business data — see sandbox skill.

## Workflow

1. **Read context** — `_state.json`, `ticket.md`, `attachments/`.

2. **Branch** — checkout then **verify** with `rev-parse`:
   - Initial-state → `base_branch` (+ pull).
   - Verification → `branch` from `_state.json`.
   Stop-gate on mismatch / empty branch.

3. **Classify sandbox scenario** + **input kind(s)** (tables above).

4. **Stand up env** via `scripts/tools/sandbox.sh --start <engine|swagger|ui>` only.
   Baseline seed if needed: `sandbox.sh --seed …`.

5. **Resolve fixtures (hierarchy above)** — search → reuse or create durable files → load into
   local DB/runtime as documented.

6. **Execute reproduction**
   - `engine`/`swagger`: capture exact request/response (+ Swagger path if applicable).
   - `ui`: Chrome DevTools observation of what rendered.
   - Fragile large payloads: clone an existing valid fixture and override only required fields.

7. **Write/update `repro.md`** (required sections below).

8. **Update `_state.json`** (`steps.repro`) and `_notes.md` per `bcs-ticket-workflow`.

9. **Cleanup** per policy above; leave sandbox running unless user asks to stop.

## `repro.md` required sections

```markdown
## Scenario
## Input kind
## Fixture resolution
## Seed / load procedure
## Reproduction call(s) / observation
## Before Fix   # or After Fix when verifying
## Required integration tests   # PRD contract — normative
## How to reproduce yourself
```

### Fixture resolution (must include)

- **Reuse?** path of existing fixture(s) + overrides, **or**
- **Created:** paths of new durable files, isolation markers (ticket key / synthetic state), and
  why shared baseline was insufficient.

### Required integration tests (must include — consumed by `/prd`)

Normative checklist for downstream agents. Example shape:

```markdown
## Required integration tests

- **IT-1:** Load fixtures `<path(s)>`; call `<method URL>`; assert `<after-fix expectation>`.
- **IT-2:** …
- **Owning suite hint:** e.g. `hoplias/test/configurations/…` or `mugil/test/…`
- **Must not:** rely on ephemeral Mongo-only overlay; fixtures must live in-repo under `test/…`
  (or be promoted there by a `[dev]` task before merge).
```

Map each IT item to the observed before/after behavior so `/prd` can promote them into Acceptance
Criteria / a dedicated PRD section without re-deriving data.

## Contract for `/prd` (and later agents)

When `repro.md` exists with **Required integration tests**:

- `/prd` **must** read it and copy/adapt into PRD section
  **## Reproduction Evidence & Required Integration Tests** (see `generate-prd` skill).
- `/spectech` may reference fixture paths as test inputs; `/tasks` **must** create explicit tasks
  to add/wire integration tests that load those fixtures and assert the after-fix behavior.
- `/dev` implements those tests; `/bcs-repro --after` reuses the **same** durable fixtures.

`/bcs-repro` does **not** write the mocha suite itself (unless the user explicitly asks in the same
session) — it owns evidence + durable data + the contract.

## Output

Report: mode (and how chosen), scenario, input kind(s), fixture reuse vs created (paths), whether
defect reproduced / fix confirmed, `repro.md` path, services left running/ports, suggested next
command (`/prd` after initial-state; `/qa` or `/summary` after verified after-fix).

## Guardrails

- **Local only** — never Sandbox/Production remotes.
- **Leave sandbox running** by default.
- **Honest reproduction** — if it did not repro, say so.
- **Verify branch after checkout.**
- **Use `sandbox.sh --status`**, never machine-wide port scans across sibling workspaces.
- **Never stand up infra by hand.**
- **Durable fixtures by default**; no Mongo-only secret seeds.
- **Do not pollute shared baseline** when isolation is required — dedicated fixture files + ticket
  prefix / synthetic keys.
- **Chrome only for `ui`.** Always `close_page`.
- Standalone — not auto-invoked by `/run`.
