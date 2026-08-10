---
description: "Local multi-service environment lifecycle for br-tax-engine + br-tax-ui: start/stop/inspect each datastore/process individually (mongo, redis, engine, mock, swagger, ui-proxy, ui) so /bcs-repro and manual Postman/Swagger/UI testing run against an already-standing environment. Standalone — not wired into /run."
argument-hint: "--start|--stop <service ... | all> | --status [service ...] | --logs <service> [-f]"
---
Load the `bcs-sandbox` skill (Read `.claude/skills/bcs-sandbox/SKILL.md`) and follow it exactly. Treat `$ARGUMENTS` as the skill's Trigger & Input.

$ARGUMENTS
