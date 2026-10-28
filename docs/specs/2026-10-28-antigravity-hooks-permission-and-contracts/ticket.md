# Issue Definition — Antigravity Hooks Permission Denied & Lifecycle Contract Alignment

- **Date:** 2026-10-28
- **Discovered in:** `beacon-applyCopilot` (consumer workspace) during `/run jira ticket APC-26`
- **Target Component:** Beacon SDD Framework (`agentic/adapters/antigravity/`, `agentic/hooks/`, `scripts/setup-agentic.sh`)

---

## 1. Primary Bug (Blocker — Exit Status 126: Permission Denied)

### Symptom
Any `run_command` tool invocation in Google Antigravity fails immediately at the `PreToolUse` hook gate:

```text
Encountered error in tool execution: JSON hook "jsonhook__beacon-shell-gate_PreToolUse_0_0" failed: command failed: exit status 126, stderr: sh: ./hooks/before-shell.sh: Permission denied
```

This completely blocks `/run`, `git-inspect.sh`, `pipeline-init.sh`, and any shell execution in Antigravity whenever the `beacon-sdd` plugin is active.

### Root Cause (Two-fold)
1. **Order of operations in `scripts/setup-agentic.sh` (`install_antigravity_plugin`, lines 687–688):**
   ```bash
   chmod +x "$plugin/hooks/"*.sh 2>/dev/null || true
   adapt_antigravity_paths "$plugin"
   ```
   Inside `adapt_antigravity_paths`, every file in `$plugin` (including `$plugin/hooks/*.sh`) is rewritten via `tmp="$(mktemp)"` (`0600` permissions) followed by `mv "$tmp" "$f"`. This overwrites all `.sh` files in `~/.gemini/config/plugins/beacon-sdd/hooks/` with mode `0600` (non-executable), wiping out the `chmod +x` applied one line earlier!
   *(Note: In `install_cursor` at lines 551–557, `adapt_cursor_paths` runs **before** `chmod +x`, which is why Cursor was not affected).*
2. **Direct script invocation in `agentic/adapters/antigravity/hooks.json`:**
   `hooks.json` invokes `"./hooks/before-shell.sh"` directly instead of `"bash ./hooks/before-shell.sh"`. Relying solely on the executable bit is fragile if file permissions are ever reset.

---

## 2. Secondary Antigravity Hook Contract Discrepancies Found During Inspection

While inspecting the Antigravity hook integration (`agentic/adapters/antigravity/hooks.json`, `agentic/hooks/*.sh`, and `agentic/hooks/lib/hook-protocol.js`) against the official Antigravity Hooks specification (`agy-customizations/docs/hooks.md`), the following mismatches were also identified:

### A. Tool Name Matchers in `agentic/adapters/antigravity/hooks.json` & `hook-protocol.js`
- In `hooks.json`:
  - `beacon-read-gate` matches `"view_file"`, whereas Antigravity's read tool is also called `read_file` (`"matcher": "view_file|read_file"`).
  - `beacon-write-gate` and `beacon-format-on-edit` match `"write_to_file|replace_file_content|multi_replace_file_content"`, whereas Antigravity also uses `write_file` and `edit_file` (`"matcher": "write_to_file|replace_file_content|multi_replace_file_content|write_file|edit_file"`).
- In `agentic/hooks/lib/hook-protocol.js`:
  - `filePathOf(input)` checks `ti.TargetFile || ti.AbsolutePath || ti.file_path || ti.filePath`, but Antigravity's `read_file`, `write_file`, and `edit_file` pass the file path in `ti.Path` (`input.toolCall.args.Path`). Without `ti.Path`, `before-read.sh`, `subagent-gate.sh`, and `format-on-edit.sh` receive an empty file path and silently no-op on `read_file`/`write_file`/`edit_file`.

### B. Missing JSON Output on `PostToolUse` and `Stop` Hooks for Antigravity
Per Antigravity's `hooks.json` contract (`Hookcommands receive context as a JSON object on stdin and must output their result as a JSON object on stdout`):
- **`PostToolUse` (`format-on-edit.sh`):** Antigravity expects an empty JSON object `{}` on stdout, and any formatter stdout (e.g., `prettier --write` printing the filename) will corrupt the JSON stdout parse in Antigravity unless redirected or suppressed before emitting `{}`.
- **`Stop` (`audit-log.sh` and `session-verify.sh`):**
  - Antigravity's `Stop` contract requires `{"decision": "allow"}` (or any value other than `"continue"`) on stdout. Currently, neither `audit-log.sh` nor `session-verify.sh` outputs JSON on stdout, which causes `Stop` hook JSON parse errors at the end of every turn in Antigravity.
  - Additionally, in `session-verify.sh`, `export HOOK_DIR="$DIR"` is missing before `node <<'NODE'` (line 14 calls `require(process.env.HOOK_DIR + "/lib/hook-protocol")` while `HOOK_DIR` was never exported in `session-verify.sh`!).

---

## 3. Recommended Fix Scope (for `/run` or `/fix` in `beacon`)

1. **`scripts/setup-agentic.sh`**:
   - In `install_antigravity_plugin()`, run `chmod +x "$plugin/hooks/"*.sh` **after** `adapt_antigravity_paths "$plugin"`.
2. **`agentic/adapters/antigravity/hooks.json`**:
   - Prefix hook commands with `bash ` (e.g., `"bash ./hooks/before-shell.sh"`) for defense-in-depth.
   - Update matchers to include `read_file`, `write_file`, and `edit_file`.
3. **`agentic/hooks/lib/hook-protocol.js`**:
   - Add `ti.Path` and `input.Path` to `filePathOf(input)`.
   - Add `read_file`, `write_file`, `edit_file` to `toolNameOf(input)`.
   - Add helper(s) for `PostToolUse` (`{}` on Antigravity) and `Stop` (`{"decision": "allow"}` on Antigravity).
4. **`agentic/hooks/format-on-edit.sh`, `audit-log.sh`, `session-verify.sh`**:
   - Export `HOOK_DIR="$DIR"` in `session-verify.sh`.
   - Suppress formatter stdout in `format-on-edit.sh` (`>/dev/null 2>&1`) and emit `{}` when running in Antigravity.
   - Emit `{"decision": "allow"}` at the end of `audit-log.sh` and `session-verify.sh` when running in Antigravity.

