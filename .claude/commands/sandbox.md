---
description: "Local multi-service environment lifecycle for br-tax-engine + br-tax-ui: start/stop/inspect each datastore/process individually (mongo, redis, engine, mock, swagger, ui-proxy, ui) so /repro and manual Postman/Swagger/UI testing run against an already-standing environment. Standalone — not wired into /run."
argument-hint: "--start|--stop <service ... | all> | --status [service ...] | --logs <service> [-f]"
---

Treat `$ARGUMENTS` as flags/service names for the local sandbox environment shared by
`br-tax-engine` and `br-tax-ui`.

## Workflow

1. **Read** `.claude/skills/sandbox/SKILL.md` (use the Read tool) and follow it as authoritative —
   this is a thin utility command, not a persona subagent (mirrors `/clone`'s and
   `/kb-refresh`'s shape). It documents the full service table (dir/port/command per service) and
   why `mongo`/`redis` are only ever brought up from `br-tax-engine`'s `docker-compose.yml`.
2. If `$ARGUMENTS` is empty or doesn't start with `--start`, `--stop`, `--status`, or `--logs`, show
   usage (run the script with no args — it prints it) and ask what the user wants, rather than
   guessing a scenario.
3. Run the helper:

   ```bash
   scripts/tools/sandbox.sh $ARGUMENTS
   ```

4. Relay its output plainly — service-by-service start/stop/status lines, and any warning (e.g. a
   port still open after `--stop`, or a health-check timeout after `--start`).
5. On a health-check timeout after `--start <service>`, point the user at
   `scripts/tools/sandbox.sh --logs <service>` before suggesting anything else.
6. Never pass `postgres` to `--start`/`--stop` yourself — the script already refuses it (native
   install, status-only), but don't second-guess that by trying to start/stop it another way.

## Guardrails

- Local only — never target Sandbox/Production or any shared/remote environment.
- Don't invent or hardcode a "scenario" flag (e.g. `--scenario ui-only`) — every service stays
  individually addressable per the skill; scenarios are just a chosen subset of service names.
- Don't bring up `br-tax-ui`'s own `docker-compose.yml` — it duplicates `mongo`/`redis` on the same
  ports as `br-tax-engine`'s and also ships prebuilt `engine`/`mock-server` containers that aren't
  used by this tool.
