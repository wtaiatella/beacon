# Antigravity Hooks Reference

Google Antigravity supports lifecycle hooks declared in `hooks.json`.

## Supported Events

| Antigravity Event | Beacon Hook Script | Matcher | Purpose |
|-------------------|-------------------|---------|---------|
| `PreToolUse` | `before-shell.sh` | `run_command` | Blocks destructive shell commands (`rm -rf /`, force push to protected branches, drop table). |
| `PreToolUse` | `before-read.sh` | `view_file` | Blocks reading secrets, credentials, and private keys. |
| `PreToolUse` | `subagent-gate.sh` | `write_to_file\|replace_file_content\|multi_replace_file_content` | Blocks editing files in repos on protected branches (`main`, `master`, `develop`, `release/*`). |
| `PostToolUse` | `format-on-edit.sh` | `write_to_file\|replace_file_content\|multi_replace_file_content` | Auto-formats edited files with prettier/gofmt/black/ruff. |
| `PreInvocation` | `session-init.sh` | — | Injects repository inventory, active spec status, and session context before model turn. |
| `Stop` | `audit-log.sh` | — | Appends session execution entry to `docs/audit.log`. |
| `Stop` | `session-verify.sh` | — | Emits warnings on uncommitted secrets, broken specs, or security markers. |

## Antigravity Hook Protocol

Antigravity invokes hooks as subprocesses communicating over standard I/O:
- **Input (`stdin`):** JSON payload with camelCase keys (`conversationId`, `stepIdx`, `toolCall`, `workspacePaths`, etc.).
- **Output (`stdout`):**
  - Gating hooks (`PreToolUse`): `{ "decision": "allow" }` or `{ "decision": "deny", "reason": "..." }`.
  - Continuation hooks (`Stop`): `{}` (allow stop) or `{ "decision": "continue", "reason": "..." }`.
  - Context injection (`PreInvocation`): `{ "injectSteps": [ { "ephemeralMessage": "..." } ] }`.
  - Post-tool hooks (`PostToolUse`): `{}`.

The shared helper `lib/hook-protocol.js` handles protocol detection and serializes responses automatically across Claude Code, Cursor, and Antigravity.
