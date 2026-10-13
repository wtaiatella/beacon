---
name: setup-workspace
description: "Interactive workspace tool registry builder. Probes each MCP server declared in .mcp.json, discovers workspace-relevant context through AI-driven exploration, asks the user only what matters, and writes docs/workspace-tools.md. Also lists project skills (outside the SDD framework) and lets the user register custom domain specialists for the pre-plan wave. Consumed by pre-plan-triage to enhance wave routing automatically."
---

# Workspace Tool Registry — Setup Skill

## Purpose

Build or incrementally update `docs/workspace-tools.md` — the workspace-level registry of
available MCP tools, their access status, and workspace-specific context (e.g. which Figma
project, which Confluence space) **plus** any custom **domain specialists** the team wants
available to the pre-plan wave beyond the 5 built-ins (`system-design`, `database`, `frontend`,
`security`, `testing-observability`) — e.g. a "payments-domain" or "tax-compliance" specialist
specific to this project — **and** the project's own skills (a repro skill that already boots
this stack, a framework skill tighter than the generic specialist). Once registered,
`pre-plan-triage` uses this context to route pre-plan waves with specificity, without the user
having to repeat it in every prompt. Whether a project skill complements or replaces a built-in
is decided per ticket by triage, not at setup time.

## Execution context

Run this skill in the **main session** (no subagent delegation). Discovery needs interactive
back-and-forth with the user; subagents cannot hold mid-task conversations.

After completing the workflow, confirm to the user that `docs/workspace-tools.md` has been updated
and remind them to re-run `/setup-workspace <name>` when a tool's config changes.

## Trigger & Input

- **Trigger:** `/setup-workspace [server-name ... | --specialist <name>] [--reset]` — arrives as `$ARGUMENTS`.
- **No args:** run setup for **all** servers declared in `.mcp.json`.
- **With server names:** re-run only the listed servers (incremental update).
- **`--specialist <name>`:** register or update **one** custom domain specialist instead of an MCP server — see **Step 2 — Domain specialists**. May be combined with server names in the same invocation; each is handled by its own step.
- **`--reset`:** wipe the registry and start fresh for all servers **and** registered specialists.

## Toolbox

- **Read, Write, Bash** — read `~/.claude/mcp.json` (global MCPs) and `.mcp.json` (project MCPs); write `docs/workspace-tools.md`.
- **All available MCP tools** — for health checks and discovery. Use whatever tool is callable
  for each server; do not assume a fixed list.

## Core principle: AI-driven, not hardcoded

There is **no per-tool script**. For each server the AI reasons about what operations exist,
probes them, and decides what to ask the user — based on what the tool actually returns, not on
a pre-written recipe. Different tools will yield different questions and different registry shapes.
The only invariant is the entry structure (see **Registry format** below).

---

## Workflow

### Step 0 — Bootstrap

1. **Discover declared MCP servers** from two sources (merge both, project wins on conflict):

   | Source | Path | Scope |
   |--------|------|-------|
   | Global | `~/.claude/mcp.json` → key `mcpServers` | available in all workspaces |
   | Project | `.mcp.json` in workspace root → key `mcpServers` | this workspace only |

   Read both files. If a server name appears in both, the project entry takes precedence (its
   command/args override the global one). The merged map is the **effective server list**.

   > **Note:** `~/.claude/settings.json` does **not** contain `mcpServers` — global MCPs live in
   > the separate `~/.claude/mcp.json` file, which is what `claude mcp add --global` writes to.

   If **neither file exists or both are empty**, warn:
   > "No MCP servers found in `~/.claude/mcp.json` (global) or `.mcp.json` (project).
   > Register servers with `claude mcp add --global <name> <command>` (global) or
   > `claude mcp add <name> <command>` (project-only), then re-run `/setup-workspace`."
   and **continue** to Step 2 (specialists, if asked) and Step 2b (project skills). Do not
   stop — a workspace with no MCP still has project skills worth registering.

   If only one source has servers, note it inline (e.g. "Found 5 global servers, no project
   `.mcp.json`.") and continue normally.

2. Read `docs/workspace-tools.md` if it exists — to know which servers are already registered
   and their last status (for incremental update and change detection).

3. Determine **target servers**: if `$ARGUMENTS` named specific servers, scope to those; otherwise
   all servers in the merged effective list.

4. Announce the plan to the user in one line: "Setting up N tool(s): [names] (global: X, project: Y).
   I'll probe each and ask only where your choice matters."

---

### Step 1 — Per-server loop (sequential, one server at a time)

For each target server:

#### 1a. Health check

Identify the simplest callable operation for this server. Use the server name and any metadata
in `.mcp.json` as hints. General heuristics (not exhaustive — adapt to what's actually available):

| Server name contains | Try first |
|---|---|
| `figma` | `whoami` or `get_metadata` |
| `glean` | `search` with a single-word query |
| `jira`, `atlassian`, `rovo` | `getAccessibleAtlassianResources` or `atlassianUserInfo` |
| `confluence` | `getConfluenceSpaces` |
| `gitlab` | `whoami` or `health_check` |
| unknown | try `whoami`, `health_check`, `list`, or `ping` in that order |

If **all attempts fail** (auth error, timeout, tool not found): mark `access: no`, record the
error message in a `**Note:**` field, and **move to the next server** — do not block the whole
setup on one inaccessible tool.

#### 1b. Discovery

If accessible, run **1–3 additional operations** to understand what workspace-relevant context
the tool exposes. The goal: find the things a user would need to choose or confirm before the
tool is useful in a pipeline. Examples of discovery logic (illustrative, not prescriptive):

- **Figma** — list files/projects the authenticated user can see; count them.
- **Confluence** — list accessible spaces; note their keys and names.
- **Jira** — list visible projects; note keys.
- **Glean** — confirm the authenticated identity; no enumerable workspace config expected.
- **GitLab** — get the authenticated user's namespace; optionally list recent projects.

Discovery is **bounded**: stop after 3 operations or when you have enough to present to the user.
Never dump raw API responses into the registry.

#### 1c. Present findings & ask

Show the user a short, plain-language summary of what was found. Then ask **only the questions
where the user's answer will change future behaviour**. Skip questions when:

- There is only one option (nothing to choose).
- The tool needs no workspace-specific config (e.g. Glean after confirming access).
- The entry already exists and nothing has changed (offer "unchanged — keep?" instead).

**Format for each question:**
> Found in [Tool]: [list of options].
> Which one(s) should I register as primary for this workspace? (or "all of them"?)

Wait for the user's answer before proceeding to 1d.

#### 1d. Write entry

Write or update the `## <server-name>` section in `docs/workspace-tools.md` with the
information gathered. See **Registry format** below for the required structure.

Print a one-line confirmation: "✓ [server-name] registered."

---

### Step 2 — Domain specialists (optional, `--specialist <name>`)

Only runs when the user passes `--specialist <name>` (or asks, in conversation, to add a
project-specific pre-plan specialist). This has nothing to do with MCP servers — it registers a
**custom** agent the team wants available to the pre-plan wave alongside the 5 built-ins
(`system-design`, `database`, `frontend`, `security`, `testing-observability`).

1. **Ask what it's for**, in plain language: "What should the `<name>` specialist ground tickets
   in? (e.g. 'payments domain rules', 'tax compliance constraints')" — one short sentence is
   enough; this becomes `Suggested use`.
2. **Ask whether an agent file already exists** for it under `agentic/agents/<name>-specialist.md`
   (or a project overlay path). If not, tell the user this registry entry alone does **not**
   create the agent — it only tells `pre-plan-triage` to consider it; the agent file itself must
   exist (point them at an existing domain specialist, e.g. `system-design-specialist.md`, as a
   template: read-only, never proposes a solution, same bounded-output contract).
3. **Write the entry** — see **Registry format** below (`## specialist: <name>`).
4. Print: "✓ specialist `<name>` registered. `pre-plan-triage` will consider it starting next `/run`."

### Step 2b — Project skills (always)

Runs on every invocation, including a server-only or `--specialist` run, and after `--reset`
(the rescan repopulates this section). This does **not** ask the user whether a skill
complements or replaces a built-in — that is `pre-plan-triage`'s call on each ticket.

1. **Find skill files.** Look for `SKILL.md` in these places, skipping any path that does not
   exist:
   - `.agents/skills/<name>/SKILL.md`
   - `.cursor/skills/<name>/SKILL.md`
   - for each child-repo directory listed under the `# --- clone-managed entries below` marker
     in `.gitignore` (one relative path per non-comment line): `<repo>/.agents/skills/<name>/SKILL.md`,
     `<repo>/.cursor/skills/<name>/SKILL.md`, and `<repo>/.claude/skills/<name>/SKILL.md`
2. **Skip the framework.** Do not register `agentic/skills/`, `.cursor/skills/beacon/`, or any
   skill whose directory is named `beacon`. Those are the SDD generics, not the project's.
3. **Read each file's frontmatter** (`name`, `description`). If `name` is missing, use the
   directory name. `Suggested use` is the description, trimmed to one sentence.
4. **Write one `## skill: <name>` section** per skill (see **Registry format**). If a previously
   registered skill file is gone, drop that section and say so in the final report.
5. Print one line per skill: "✓ skill `<name>` registered (`<path>`)." If none were found, say
   "No project skills found." and leave no `## skill:` sections.

### Step 3 — Final report

After all servers and specialists, print a summary table:

```
| Tool / specialist | Kind       | Status      | Key config                  |
|--------------------|-----------|-------------|------------------------------|
| figma              | mcp       | verified ✓  | Project: "BR Tax UI Design"  |
| confluence         | mcp       | verified ✓  | Space: BR-TAX                |
| glean              | mcp       | verified ✓  | No workspace config needed   |
| payments-domain    | specialist| registered  | Grounds tickets in payments  |
| reproduce-issue    | skill     | registered  | Boots this stack and reproduces |
```

Then remind:
> "Registry saved to `docs/workspace-tools.md`. Re-run `/setup-workspace <name>` anytime to
> update a specific tool, or `/setup-workspace --specialist <name>` to update a specialist entry.
> Project skills are refreshed on every run. The registry is read automatically by
> pre-plan-triage on every `/run`."

---

## Registry format (`docs/workspace-tools.md`)

Free-form Markdown. The file starts with a header block, then one section per registered
**MCP server** (`## <server-name>`), registered **domain specialist**
(`## specialist: <name>`), or discovered **project skill** (`## skill: <name>`). Required
fields per section; everything else is free-form.

```markdown
# Workspace Tools Registry
_Last updated: <YYYY-MM-DD> · Updated by: /setup-workspace_

---

## <server-name>

- **Status:** verified ✓   ← or: not accessible ✗ / skipped
- **Access:** yes           ← or: no
- **Suggested use:** <one sentence: when pre-plan-triage should activate this tool>

<Free-form discovered context. Examples:>
- Discovered files / projects / spaces (list only what's relevant)
- User's selected primary resource (name + URL/key if applicable)
- Any notes about scope or limitations

---

## specialist: <name>

- **Agent file:** agentic/agents/<name>-specialist.md   ← or a project overlay path
- **Suggested use:** <one sentence: when pre-plan-triage should include this specialist>

---

## skill: <name>

- **Path:** .cursor/skills/<name>/SKILL.md   ← workspace-relative path to that SKILL.md
- **Suggested use:** <one sentence from the skill's description>
```

**Required field semantics (MCP server sections):**

| Field | Values | Purpose |
|---|---|---|
| `Status` | `verified ✓` / `not accessible ✗` / `skipped` | Health check result |
| `Access` | `yes` / `no` | Whether the tool responded |
| `Suggested use` | one sentence | Consumed by pre-plan-triage to decide if wave applies |

**Required field semantics (specialist sections):**

| Field | Values | Purpose |
|---|---|---|
| `Agent file` | path | Where `pre-plan-triage` / the orchestrator finds the agent to delegate `Task(...)` to |
| `Suggested use` | one sentence | Consumed by `pre-plan-triage` to decide if this ticket needs it |

There is no `Status`/`Access` for a specialist entry — unlike MCP servers, there's nothing to
health-check; the entry either exists (and its agent file is assumed to exist) or it doesn't.

**Required field semantics (project skill sections):**

| Field | Values | Purpose |
|---|---|---|
| `Path` | workspace-relative path | Where triage and the orchestrator read the procedure |
| `Suggested use` | one sentence | Consumed by `pre-plan-triage` to decide if this ticket should use the skill, and whether it complements or replaces a built-in |

**Suggested use examples (adapt to what was discovered):**
- "Activate when PRD involves UI, screens, or component design in web-ui."
- "Activate when ticket involves Migrate Standard integration or ISS retention rules."
- "Activate for broad enterprise knowledge search when ticket context is ambiguous."
- *(specialist)* "Activate when the ticket touches payment processing or billing cycles."
- *(skill)* "Boots this project's services and reproduces the reported issue end to end."

---

## Guardrails

- **Never store credentials, tokens, or API keys** in the registry — only names, keys, and URLs.
- **Never overwrite a verified entry with a failed probe** without asking the user. If a tool
  that was `verified ✓` now fails, surface this explicitly: "Tool X was verified before but
  failed today — keep old entry or mark as not accessible?"
- **Full rewrite on write** — rewrite the whole `docs/workspace-tools.md` file (not append) to
  avoid stale partial entries from previous runs.
- **No assumptions about importance** — do not decide which tool is "primary" without asking.
- **Incremental by default** — if `$ARGUMENTS` names specific servers, touch only those entries;
  leave others unchanged.
- **If `docs/` does not exist**, create it before writing.
- **Source annotation** — in each registry entry, note whether the server came from `global` or `project` config. This helps the user know where to edit if they want to remove a server.
- **Specialist entries never fabricate an agent.** Registering `## specialist: <name>` only tells `pre-plan-triage` to consider it; this skill does **not** create `agentic/agents/<name>-specialist.md` for the user. If the file doesn't exist yet, say so plainly and point at an existing domain specialist as a template.
- **Skill entries are a catalog, not a routing decision.** Do not ask the user, and do not write, whether a skill complements or replaces a built-in. Record path and description only. `pre-plan-triage` decides that per ticket.
