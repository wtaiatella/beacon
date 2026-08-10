# Cursor Hooks Reference

Condensed reference for hook events, input/output schemas, and configuration. Source: official Cursor hooks documentation.

**This file is the canonical source of truth for hook field names.** Always reference it when writing or modifying hook scripts to prevent field-name bugs.

## Configuration

Hooks are defined in `hooks.json`. Locations (highest priority first):

1. **Enterprise** (MDM): `/Library/Application Support/Cursor/hooks.json` (macOS)
2. **Team** (cloud-distributed, Enterprise only)
3. **Project**: `<project>/.cursor/hooks.json`
4. **User**: `~/.cursor/hooks.json`

All matching hooks from every source run; higher-priority sources take precedence on conflict.

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {
        "command": ".cursor/hooks/my-hook.sh",
        "timeout": 30,
        "matcher": "curl|wget",
        "failClosed": false
      }
    ]
  }
}
```

### Per-Hook Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `command` | string | required | Script path (relative to hook source root). |
| `type` | `"command"` \| `"prompt"` | `"command"` | Execution type. |
| `timeout` | number | platform default | Timeout in seconds. |
| `loop_limit` | number \| null | 5 | Per-script loop limit for `stop`/`subagentStop`. null = no limit. |
| `failClosed` | boolean | false | If true, hook failures block the action (instead of fail-open). |
| `matcher` | string | -- | Regex filter for when hook runs. What it matches depends on hook type. |

### Exit Code Behavior

| Exit Code | Meaning |
|-----------|---------|
| 0 | Hook succeeded, use JSON output. |
| 2 | Block the action (equivalent to `permission: "deny"`). |
| Other | Hook failed; action proceeds (fail-open by default). |

## Common Input Fields (All Hooks)

Every hook receives these base fields alongside hook-specific fields:

```json
{
  "conversation_id": "string",
  "generation_id": "string",
  "model": "string",
  "hook_event_name": "string",
  "cursor_version": "string",
  "workspace_roots": ["path"],
  "user_email": "string | null",
  "transcript_path": "string | null"
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CURSOR_PROJECT_DIR` | Workspace root directory. |
| `CURSOR_VERSION` | Cursor version string. |
| `CURSOR_USER_EMAIL` | Authenticated user email (if logged in). |
| `CURSOR_TRANSCRIPT_PATH` | Conversation transcript path (if enabled). |
| `CURSOR_CODE_REMOTE` | `"true"` when in a remote workspace. |
| `CLAUDE_PROJECT_DIR` | Alias for project dir (Claude compatibility). |

## Hook Event Schemas

### `subagentStart`

Called before spawning a subagent (Task tool). Can allow or deny.

**Matcher:** Matches against `subagent_type` (e.g. `explore|shell|generalPurpose`).

**Input:**
```json
{
  "subagent_id": "string",
  "subagent_type": "string",
  "task": "string",
  "parent_conversation_id": "string",
  "tool_call_id": "string",
  "subagent_model": "string",
  "is_parallel_worker": false,
  "git_branch": "string (optional)"
}
```

**Output:**
```json
{
  "permission": "allow | deny",
  "user_message": "string (optional)"
}
```

Note: `"ask"` is accepted by schema but treated as `"deny"` for subagentStart.

---

### `subagentStop`

Called when a subagent completes, errors, or is aborted.

**Matcher:** Matches against `subagent_type`.

**Input:**
```json
{
  "subagent_type": "string",
  "status": "completed | error | aborted",
  "task": "string",
  "description": "string",
  "summary": "string",
  "duration_ms": 0,
  "message_count": 0,
  "tool_call_count": 0,
  "loop_count": 0,
  "modified_files": ["string"],
  "agent_transcript_path": "string | null"
}
```

**Output:**
```json
{
  "followup_message": "string (optional)"
}
```

---

### `beforeShellExecution`

Called before any shell command executes.

**Matcher:** Matches against the shell command string.

**Input:**
```json
{
  "command": "string",
  "cwd": "string",
  "sandbox": false
}
```

**Output:**
```json
{
  "permission": "allow | deny | ask",
  "user_message": "string (optional)",
  "agent_message": "string (optional)"
}
```

---

### `afterShellExecution`

Fires after a shell command executes.

**Input:**
```json
{
  "command": "string",
  "output": "string",
  "duration": 0,
  "sandbox": false
}
```

**Output:** No output fields.

---

### `beforeReadFile`

Called before Agent reads a file.

**Matcher:** Matches against tool type (`TabRead`, `Read`, etc.).

**Input:**
```json
{
  "file_path": "string",
  "content": "string",
  "attachments": [{ "type": "file | rule", "file_path": "string" }]
}
```

**Output:**
```json
{
  "permission": "allow | deny",
  "user_message": "string (optional)"
}
```

---

### `afterFileEdit`

Fires after Agent edits a file.

**Matcher:** Matches against tool type (`TabWrite`, `Write`, etc.).

**Input:**
```json
{
  "file_path": "string",
  "edits": [{ "old_string": "string", "new_string": "string" }]
}
```

**Output:** No output fields currently supported.

---

### `beforeMCPExecution`

Called before an MCP tool executes.

**Input:**
```json
{
  "tool_name": "string",
  "tool_input": "string (JSON params)"
}
```
Plus either `{ "url": "string" }` or `{ "command": "string" }`.

**Output:**
```json
{
  "permission": "allow | deny | ask",
  "user_message": "string (optional)",
  "agent_message": "string (optional)"
}
```

---

### `afterMCPExecution`

Fires after an MCP tool executes.

**Input:**
```json
{
  "tool_name": "string",
  "tool_input": "string",
  "result_json": "string",
  "duration": 0
}
```

**Output:** No output fields.

---

### `preToolUse`

Called before any tool execution (generic, fires for all tools).

**Matcher:** Matches against tool type (`Shell`, `Read`, `Write`, `Task`, `MCP:<tool_name>`).

**Input:**
```json
{
  "tool_name": "string",
  "tool_input": {},
  "tool_use_id": "string",
  "cwd": "string",
  "model": "string",
  "agent_message": "string"
}
```

**Output:**
```json
{
  "permission": "allow | deny",
  "user_message": "string (optional)",
  "agent_message": "string (optional)",
  "updated_input": {}
}
```

---

### `postToolUse`

Called after successful tool execution.

**Matcher:** Matches against tool type.

**Input:**
```json
{
  "tool_name": "string",
  "tool_input": {},
  "tool_output": "string (JSON)",
  "tool_use_id": "string",
  "cwd": "string",
  "duration": 0,
  "model": "string"
}
```

**Output:**
```json
{
  "updated_mcp_tool_output": {},
  "additional_context": "string (optional)"
}
```

---

### `postToolUseFailure`

Called when a tool fails, times out, or is denied.

**Input:**
```json
{
  "tool_name": "string",
  "tool_input": {},
  "tool_use_id": "string",
  "cwd": "string",
  "error_message": "string",
  "failure_type": "timeout | error | permission_denied",
  "duration": 0,
  "is_interrupt": false
}
```

**Output:** No output fields currently supported.

---

### `sessionStart`

Called when a new conversation is created. Fire-and-forget.

**Input:**
```json
{
  "session_id": "string",
  "is_background_agent": false,
  "composer_mode": "agent | ask | edit"
}
```

**Output:**
```json
{
  "env": { "KEY": "VALUE" },
  "additional_context": "string (optional)"
}
```

---

### `sessionEnd`

Called when a conversation ends. Fire-and-forget.

**Input:**
```json
{
  "session_id": "string",
  "reason": "completed | aborted | error | window_close | user_close",
  "duration_ms": 0,
  "is_background_agent": false,
  "final_status": "string",
  "error_message": "string (optional)"
}
```

**Output:** No output fields (fire and forget).

---

### `beforeSubmitPrompt`

Called after user hits send but before backend request.

**Matcher:** Matches against `UserPromptSubmit`.

**Input:**
```json
{
  "prompt": "string",
  "attachments": [{ "type": "file | rule", "file_path": "string" }]
}
```

**Output:**
```json
{
  "continue": true,
  "user_message": "string (optional)"
}
```

---

### `preCompact`

Called before context window compaction. Observational only.

**Input:**
```json
{
  "trigger": "auto | manual",
  "context_usage_percent": 85,
  "context_tokens": 120000,
  "context_window_size": 128000,
  "message_count": 45,
  "messages_to_compact": 30,
  "is_first_compaction": true
}
```

**Output:**
```json
{
  "user_message": "string (optional)"
}
```

---

### `stop`

Called when the agent loop ends. Can auto-submit a follow-up.

**Matcher:** Matches against `Stop`.

**Input:**
```json
{
  "status": "completed | aborted | error",
  "loop_count": 0
}
```

**Output:**
```json
{
  "followup_message": "string (optional)"
}
```

---

### `afterAgentResponse`

Called after the agent completes an assistant message.

**Matcher:** Matches against `AgentResponse`.

**Input:**
```json
{
  "text": "string"
}
```

**Output:** No output fields.

---

### `afterAgentThought`

Called after agent completes a thinking block.

**Matcher:** Matches against `AgentThought`.

**Input:**
```json
{
  "text": "string",
  "duration_ms": 0
}
```

**Output:** No output fields.

---

### Tab-Specific Hooks

**`beforeTabFileRead`** — Before Tab reads a file (no attachments field). Output: `{ permission }`.

**`afterTabFileEdit`** — After Tab edits a file. Input includes detailed range info (`start_line_number`, `start_column`, `end_line_number`, `end_column`, `old_line`, `new_line`). No output fields.
