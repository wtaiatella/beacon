# Running Notes — 2026-10-28-antigravity-hooks-permission-and-contracts

- **2026-10-28T08:48:00-03:00 | ticket_intake | recorded**
  - Finding discovered while starting `/run jira ticket APC-26` in consumer workspace `beacon-applyCopilot` under Google Antigravity IDE.
  - `beacon-shell-gate` (`PreToolUse` on `run_command`) failed with `exit status 126, stderr: sh: ./hooks/before-shell.sh: Permission denied` because `setup-agentic.sh` ran `adapt_antigravity_paths` (`mv "$tmp" "$f"`) *after* `chmod +x "$plugin/hooks/"*.sh`, stripping the `+x` mode bits on all hook scripts.
  - Additional Antigravity hook contract discrepancies identified in `hooks.json` and `agentic/hooks/*.sh` (tool matchers, `PostToolUse` `{}` stdout, `Stop` `{"decision":"allow"}` stdout, and `filePathOf` support for `Path`).
  - Next step: run `/prd` or `/run` on `docs/specs/2026-10-28-antigravity-hooks-permission-and-contracts/` in the `beacon` workspace, merge to `main`, and run `scripts/upgrade.sh` in consumer workspaces.

