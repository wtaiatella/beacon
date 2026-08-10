# Cursor Agents & Task Tool Reference

Condensed reference for subagent configuration and the Task tool. Source: official Cursor subagents documentation.

## Agent File Format

Agent definitions live in `.cursor/agents/` (project) or `~/.cursor/agents/` (user). Each is a markdown file with YAML frontmatter.

```yaml
---
name: my-agent
description: "Short description. Agent reads this to decide delegation."
model: inherit
readonly: false
is_background: false
---
```

### Frontmatter Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | No | From filename | Display name and identifier. Lowercase + hyphens. |
| `description` | string | No | -- | Short description. Cursor reads this to decide when to delegate. |
| `model` | string | No | `inherit` | Model to use: `inherit`, `fast`, or a specific model ID. |
| `readonly` | boolean | No | `false` | If true, restricted write permissions (no file edits, no state-changing shell). |
| `is_background` | boolean | No | `false` | If true, runs in background without blocking parent. |

### Model Values

| Value | Behavior |
|-------|----------|
| `inherit` | Uses same model as parent agent (default). |
| `fast` | Smaller, faster model optimized for speed and cost. |
| Specific ID | Exact model, e.g. `claude-4-sonnet`. See model catalog. |

**When model config is ignored:** Admin restrictions, Max Mode required but not enabled, model not available on current plan. Cursor falls back to a compatible model.

## Task Tool (Subagent Delegation)

The Task tool launches specialist subagents. Each subagent operates in its own context window.

### Available `subagent_type` Values

Built-in types: `generalPurpose`, `explore`, `shell`, `best-of-n-runner`

Custom types (from `.cursor/agents/`): match the agent filename without `.md`. In this workspace: `plan`, `dev`, `sre`, `data`, `qa`, `do`, `fix`, `summary`, `scrum`, `kb`, `codebase-explorer`, `spec-validator`, `security-scanner`, `plan-reviewer`, `dev-reviewer`, `sre-reviewer`, `data-reviewer`, and **pre-plan / MCP read-only** helpers: `pre-plan-triage`, `mcp-glean`, `mcp-confluence`, `mcp-jira`, `mcp-gitlab`, **`mcp-arc`** (orchestrator-gathered context for **`/run`** pre-plan when triage requires ARC; see **`docs/run-pipeline-reference.md`** and **`docs/reference/arc-mcp-workflow.md`**). **`/run`** is not a subagent — it invokes the **`run-pipeline`** skill in the main session. Under **orchestrated** **`/run`**, **`Task(codebase-explorer)`**, **`Task(spec-validator)`**, and **`Task(security-scanner)`** are scheduled **only** by that main session (**codebase-explorer** escalation and **QA prep wave** — see **`.cursor/skills/run-pipeline/SKILL.md`**, **ROAD-50**); implementation personas **do not** call those **`Task`** types themselves (flat orchestration; use **`REQUEST_MAIN:`** where applicable).

**ARC MCP (AvaTax Release Central, ROAD-25 / ROAD-47):** Two lanes — **(A)** **`/run`** pre-plan: the main session may delegate **`Task(mcp-arc)`** in parallel with other **`Task(mcp-*)`** when **`Task(pre-plan-triage)`** indicates ARC / AvaTax / RC / schema / catalog needs (flat orchestration, not nested inside **`Task(plan)`**). **(B)** In-session: **`/plan`** and **`/kb`** (where applicable) may call ARC MCP tools **directly** in their own sessions when configured. Under orchestrated **`/run`**, **`/dev`** and **`/fix`** **do not** call ARC directly — they return **`REQUEST_MAIN: ARC <query>`** and the orchestrator runs **`Task(mcp-arc)`** (see **`run-pipeline`** — **Mid-run enterprise context**). Lane **(B)** does **not** replace lane **(A)** when triage already required ARC for **`/run`**. See **`docs/reference/arc-mcp-workflow.md`** (**Two lanes**), **`docs/reference/mcp-servers-inventory.md`**, and **`.cursor/rules/00-workspace-router.mdc`**.

### Task Tool Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `subagent_type` | Yes | Agent type from the enum above. |
| `prompt` | Yes | Task description with all necessary context. |
| `description` | Yes | Short 3-5 word summary. |
| `model` | No | Override model for this agent. |
| `readonly` | No | Override readonly mode. |
| `run_in_background` | No | Run without blocking parent. |
| `resume` | No | Agent ID to resume a previous invocation. |

### Foreground vs Background

| Mode | Behavior | Best For |
|------|----------|----------|
| Foreground | Blocks until complete. Returns result immediately. | Sequential tasks needing output. |
| Background | Returns immediately. Agent works independently. | Long-running or parallel workstreams. |

## Await Tool (Cursor 3.0+)

The `Await` tool lets agents wait for background shell commands and subagents to complete, or wait for specific output patterns.

**Usage with background subagents:**
1. Launch a Task with `run_in_background: true` — returns immediately with an agent ID.
2. Call `Await(task_id=<agent_id>)` to wait for the background agent to complete.
3. The Await result contains the subagent's output.

**Pattern: parallel background Tasks + Await collection:**
```
Task(dev, run_in_background=true)    → returns dev_id
Task(sre, run_in_background=true)    → returns sre_id
Await(task_id=dev_id)                → returns dev result
Await(task_id=sre_id)                → returns sre result
```

This cuts parallel workloads from `N * agent_time` to `max(agent_time)`.

## `is_background` Frontmatter

Set `is_background: true` in agent frontmatter to make the agent always run in background mode:

```yaml
---
name: my-agent
is_background: true
---
```

Alternatively, pass `run_in_background: true` as a Task parameter for per-invocation control.

## Key Constraints

- **Context isolation:** Each subagent starts with a clean context window. No access to prior conversation history. The parent must include all relevant information in the prompt.
- **Nested subagents:** Subagents can launch child subagents (since Cursor 2.5). Requires Task tool access in current mode.
- **Resume:** Each execution returns an agent ID. Pass this ID to resume with full context preserved.
- **Parallel execution:** Launch multiple subagents concurrently by making multiple Task tool calls in a single message. Use `run_in_background: true` + `Await` for fine-grained control.

### Nested `Task` / subagent reliability (product constraint)

**Nested delegation** means a subagent (or persona) invokes **`Task`** again so a child subagent runs inside the parent’s turn. Depth grows when, for example, the main session calls **`Task(dev)`**, and **`dev`** calls **`Task(codebase-explorer)`** or another specialist. **This workspace’s orchestrated `/run` flow does not use that pattern for specialists:** the **main session** sequences **`Task(plan)`**, **`Task(dev)`**, **`Task(codebase-explorer)`** (on **`REQUEST_MAIN`**), **`Task(spec-validator)`** / **`Task(security-scanner)`** (QA prep), **`Task(qa)`**, etc. — personas return **`REQUEST_MAIN:`** or work from injected artifacts instead of nesting **`Task`**.

**Observed behavior (Cursor product — not a guarantee of this repo):** Nested chains can **fail, truncate, or behave inconsistently** on sessions that use **lower-capability models or tiers**. Teams often report **reliable** nesting only when the **session** is on **max** tier (or an org-approved equivalent with similar capability). Economy- or standard-tier session models may still run top-level **`Task`** calls but are **not** a safe assumption for deep **`Task` → `Task`** chains.

**Guidance**

- Prefer **max** tier (or your organization’s default for **deep delegation**) for the **main session** when running **`/run`** or other flows that rely on **many sequential top-level** **`Task`** calls from the orchestrator (not nested persona **`Task`** chains).
- **ROAD-28** (`apply-models.sh` per-step IDs) and **ROAD-36** (manual `models.user.yml`) control **which model ID** is written to agent frontmatter — they do **not** remove **session-level** limits on nested tooling. If nested **`Task`** fails, try a **higher session tier** before changing YAML alone.
- See **`docs/run-pipeline-reference.md`** (Parallelism / nested delegation) for how this fits **orchestrated** pipelines.

Framing: **Cursor** sets model availability and nesting behavior; this workspace **documents** team practice, not product SLAs.

## Best Practices

- Write focused agents with single, clear responsibility.
- Invest in the `description` field — it determines when Cursor auto-delegates.
- Keep prompts concise and specific.
- Add agents to version control (`.cursor/agents/`).
- Use `readonly: true` for agents that should never modify files.

## Anti-Patterns

- Dozens of vague agents ("helps with coding") — Agent won't know when to use them.
- Overly long prompts (2000+ words) — slower, harder to maintain.
- Duplicating what slash commands or skills can do — use skills for single-purpose tasks.
