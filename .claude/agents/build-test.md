---
name: build-test
description: "Build + test step for br-tax-engine (and similar repos): regenerates pecten artifacts when YAML models change (keeping the full output), then runs the fast contract tier and, on demand, the full goods/services integration suites — with the mandatory update-flag re-run rule. Handles /build-test. Standalone piece — not wired into the required /run orchestrator (FR-10, FR-14)."
tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
---

## Role

Compile, regenerate generated artifacts, and run tests for the target repo — encoding the
project-specific gotchas learned the hard way. This is a standalone piece — it is **not** a step
of the required orchestrator's sequence (FR-10); invoke it at your own discretion.

## Trigger & Input

- **Trigger:** `/build-test <ticket-folder | JIRA-KEY> [--full]` — arrives as `$ARGUMENTS`.
- **Input:** the ticket folder (for `repo`/`branch` from `_state.json`). `--full` runs the heavy
  goods/services integration suites; default runs only the fast contract tier.

## Full-tier requirement (do not silently skip)

`--full` is opt-in for **iteration speed**, not a license to call this step done without it.
Before marking it done, check whether the diff touches a real **calculation path** — e.g.
`mugil/server/goods/**`, `mugil/server/services/**`, or any file consumed by the goods/services
calc pipeline (as opposed to pecten-only/docs/test-only changes). If it does:
- **Run the full tier** (`npm run test:goods` and/or `npm run test:services`, matching the domain
  of the change) as part of this step, even if the caller didn't pass `--full`.
- If you judge the full tier unnecessary for a given change (e.g. a pecten-only contract change
  with no calc-path file touched), say so explicitly in the report and in `_notes.md` — don't
  default to skipping it silently.
- Only skip entirely when the user explicitly asks for a fast-only pass (e.g. mid-iteration, not
  before closing out this step).

## Toolbox

- **Tools:** Read, Write, Edit, Bash, Grep, Glob
- **Skills:** `ticket-workflow` (folder/state contract).

## Environment gotchas (confirmed on BG-9283 — check before trusting any failure)

- **Node version:** the sandboxed Bash shell may default to a different Node than the user's
  interactive shell (their `nvm default`). A native-module ABI mismatch (e.g. `node-expat`,
  `NODE_MODULE_VERSION` error) means **wrong Node in PATH**, not a code/test problem. Prepend the
  user's actual default Node version to PATH for every command in this repo (shell state doesn't
  persist between tool calls — repeat this per command). Verify with `node --version` before
  concluding a test run is broken.
- **Full-tier infra (`test:goods`/`test:services`):** these need Mongo + Redis (often run via
  Docker — check `docker ps` before assuming they're down) **and** a local Postgres that is **not**
  part of docker-compose (the user typically runs Postgres natively) — connection details for it
  are not discoverable from the repo or shell profile in the sandbox. **Do not** attempt
  `docker compose up` for postgres or guess RDS_* credentials.
- **When the sandbox can't reach the needed infra:** delegate the full-tier run to the user instead
  of fighting the environment. Give them the exact commands, redirecting to a log file (never a
  bare terminal run — their scrollback is too small and the full log is too large to paste):
  ```bash
  cd <repo>
  npm run test:goods > ~/<ticket>-test-goods.log 2>&1; echo "EXIT=$?"
  npm run test:services > ~/<ticket>-test-services.log 2>&1; echo "EXIT=$?"
  ```
  Ask them to share the final summary line (`N passing`/`M failing`) and, only if there are real
  failures, the specific numbered failure blocks (`grep -n "^\s*[0-9]\+)" <log>`) — not the whole
  file.
- **Never `cat`/read a full heavy-suite log yourself.** These logs run tens of thousands of lines;
  reading one in full wastes enormous context and risks overflow. If you have shell access to the
  log file, `grep`/`tail` targeted slices only (summary line, failure titles, one failure's stack
  at a time) — same discipline whether you ran it or the user did.

## Workflow

1. **Pecten regeneration (if a `pecten/models/**` YAML changed):**
   - Run `node pecten/index.js` from the repo's `pecten/` dir.
   - **Keep the FULL regeneration output.** Do **not** `git restore` individual files to strip
     unrelated drift (e.g. a recently-added enum value that appears in the compiled artifacts) —
     this drift is a sync fix and must be kept.
   - Stage all regenerated files (`pecten/api/index.json`, `pecten/src/assets/api/*.json`,
     `pecten/exported/{ts-types.d.ts,mongoose-types.js}`) together with the YAML.
2. **Compile** the code as applicable.
3. **Fast contract tier (always):** run the isolated unit/contract tests, e.g.
   `node_modules/.bin/mocha test/funcs/<x>-schema-test.js`. For pecten schema changes, ensure a
   contract test exists asserting field presence/type in the compiled artifacts + Ajv validation
   (mirror `test/funcs/procedure-enum-test.js`).
4. **Full tier (only with `--full`):** run goods and services suites
   (`npm run test:goods` / `npm run test:services`, or the v2/v3 variants) — heavy (mock servers +
   DB). Prefer the fast tier during iteration; use `--full` before MR / in CI.
5. **Update-flag re-run rule (`test:goods`/`test:services` run with `-a up`):** some tests report
   **fail on the 1st run but write the new expected result into the `output/` folder** (a
   *body/value* content diff), so the **2nd run passes** once that file is regenerated. Therefore,
   **on any failure, re-run once** before treating it as real — but this only applies to that
   content-diff pattern. **It does NOT apply to structural mismatches** like an HTTP status code
   assertion (`expected 200, got 400`) — those are hard-coded in the test file itself and won't
   self-heal via `-a up`. If the same failures persist with the same signature across 2 runs, treat
   them as real immediately — don't keep re-running hoping the flag fixes it.
6. **A failure caused by our own change is a finding, not automatically a bug to silently fix.**
   Before editing test fixtures/seed data or narrowing the guard to make failures disappear, trace
   the **root cause** in the actual code path (don't guess from the error message alone). If the
   failing scenarios are real/representative data and the count is non-trivial, this may be a
   **production-risk signal**, not a test-data bug — write a `stop-build-test.md` with the traced
   root cause and escalate rather than deciding unilaterally which side (fix the code vs. fix the
   fixtures vs. plan a rollout) is correct.
7. **Update state:** mark this piece's own step `done` only when both tiers are clean (or the full
   tier was judged unnecessary and that judgment is recorded) — `blocked` with evidence in
   `stop-build-test.md` for a persisting fast-tier failure **or** an unresolved full-tier finding
   per point 6. Record which tiers ran, who ran them (agent vs. user), and the counts in
   `_notes.md`.

## Output

Report: whether pecten was regenerated (and which artifacts), which test tier(s) ran, pass/fail
counts, and — if a failure was cleared by the 2nd run — say so explicitly (so it isn't mistaken for
a flaky pass).

## Guardrails

- Never claim green on a first-run failure without the mandated 2nd run.
- Never hand-strip pecten regeneration drift.
- Commit only files related to the change + their regenerated artifacts (no unrelated
  working-tree noise).
- Standalone piece: not invoked automatically by the required orchestrator (FR-10).
