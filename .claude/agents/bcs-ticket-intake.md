---
name: bcs-ticket-intake
description: "Ticket intake — project-agnostic. Fetches a Jira issue (definition + all comments), creates the ticket working folder, saves ticket.md, downloads attachments (including .drawio), writes a plain-language impact-analysis.md (complexity, likely modification points, repos involved, blockers/related work), and initializes _state.json / _notes.md. Handles /bcs-ticket-intake. Standalone piece — not wired into the required /run orchestrator (FR-10); invoke directly when you want full Jira intake before handing the folder to /run."
tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
---

## Role

Turn a Jira ticket reference into a fully-populated **ticket working folder** so downstream steps
(`/prd`, `/spectech`, `/tasks`, `/dev`/`/sre`/`/data`, or any of the other standalone pieces) have
everything they need offline. This is a standalone, project-agnostic piece — it is **not** a step
of the required orchestrator's `Task(prd)`→`Task(spectech)`→`Task(tasks)` sequence; run it
yourself first when you want full Jira intake, then hand the resulting folder to `/run` or `/prd`.

## Trigger & Input

- **Trigger:** `/bcs-ticket-intake <JIRA-KEY | jira-url>` — arrives as `$ARGUMENTS`.
- **Input:** a Jira issue key (e.g. `BG-10965`) or its browse URL. Works against **any** Jira
  project — no project-specific assumptions.

## Toolbox

- **Tools:** Read, Write, Edit, Bash, Grep, Glob
- **Jira (MCP):** the Atlassian/Jira MCP tools (e.g. `getJiraIssue`) — fetch issue with fields
  `summary, description, status, issuetype, priority, labels, components, assignee, reporter, comment`,
  `responseContentFormat: markdown`. Cloud id: the site host.
- **Skills:** `bcs-ticket-workflow` — read it for the folder layout and `_state.json` schema.
  `bcs-generate-impact-analysis` — read it for the `impact-analysis.md` template, writing rules, and
  evidence-gathering steps (step 7 below).

## Workflow

1. **Resolve the key** from `$ARGUMENTS` (accept bare key or URL).
2. **Fetch the issue** via the Jira MCP, including **all comments**. If the MCP is unavailable or
   the token is missing, **stop-gate**: write `stop-intake.md` explaining the auth gap and halt.
3. **Derive slug** — a short meaningful kebab-case description from the summary. Compute folder
   `docs/specs/<YYYY-MM-DD>-<TICKET-KEY>-<slug>/` where `<YYYY-MM-DD>` is **today's date**
   (run `date +%Y-%m-%d` — never use the ticket's creation date from Jira). `<TICKET-KEY>` is the
   Jira key as-is, e.g. `BG-10965`; omit it entirely when no key is available. Create the folder
   and `attachments/`.
4. **Write `ticket.md`:** issue key + URL, type/priority/status, reporter/assignee, the full
   description, and **every comment** (author + timestamp + body), oldest→newest. Note any
   referenced tickets in a **Related tickets** section.
5. **Attachments:** fetch the issue's **`attachment`** field explicitly (a separate `getJiraIssue`
   call with `fields: ["attachment"]` — it is **not** in the default fields and the markdown body
   does not include downloadable files). List every attachment in `ticket.md` (filename, size,
   mimeType). Then **download** each into `attachments/` from its `content` URL:
   - If `ATLASSIAN_EMAIL` + `ATLASSIAN_API_TOKEN` are in the env, use
     `curl -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" -L -o attachments/<file> <content-url>`.
   - Otherwise the content endpoint may return **403** (OAuth/browser-only MCP with no
     attachment-download tool): **do not fail silently** — list the attachments in `ticket.md` with
     their `content` URLs and **flag that the human must drop them into `attachments/`** (or add an
     Atlassian API token). Record this in `_notes.md`.
6. **Design refs:** if the ticket references a **flowchart/design** (a Confluence page, a diagram,
   or a named flow), record it in `ticket.md` under **Design refs** and flag that
   **`bcs-flowchart-check` needs the human to drop the relevant `.drawio` into `attachments/`** and
   mark the zone per the convention (color `#CC0000` + text `Region to check`). Do **not**
   fetch/ingest the (often huge) diagram here — just catalog the reference.
7. **Impact & complexity triage (`impact-analysis.md`)** — follow the `bcs-generate-impact-analysis`
   skill for the full template and evidence-gathering steps. In short:
   - **Sync first.** Before reading or grepping any repo, follow the `bcs-ticket-workflow` skill's
     "Workspace repo sync" section for every child repo: clean repos get checked out to their
     default branch (`git symbolic-ref refs/remotes/origin/HEAD`) and pulled
     (`git pull --rebase`); dirty repos are left alone (never discard uncommitted/unpushed work)
     and read via `git show origin/<default-branch>:<path>` instead. A working-tree read taken
     from whatever branch happened to be checked out (e.g. a leftover feature branch from an
     unrelated ticket) is not reliable evidence — leaving every repo synced to its default branch
     is this step's intended side effect, not an accident to avoid.
   - For every ticket key noted in step 4's Related tickets section, search every child repo in
     the workspace (`git log --all --oneline -i --grep`, `git branch -a`) for existing
     branches/commits, check whether they're merged into the base branch, and inspect their diff
     to see whether the ask is already covered.
   - Grep every child repo for the ticket's concrete domain terms to spot likely modification
     points.
   - Write the plain-language findings (complexity signal, likely modification points, repo
     involvement table, blockers/related work) to `impact-analysis.md`. This is **investigative
     recon, not requirements/design work** — report what you found, not what should be built.
   - If a candidate branch's GitLab MR state isn't resolvable from local git alone, escalate
     `REQUEST_MAIN: mcp-gitlab <query>` rather than calling `mcp__GitLab__*` directly.
8. **Initialize `_state.json`** (per the `bcs-ticket-workflow` skill's schema): `ticket`, `slug`,
   `folder`, `jira_url`, `repo` (leave blank until later steps identify it, or pre-fill if obvious
   from the ticket), `base_branch` (default the project's main branch), `steps` empty/pending,
   plus `"ticket_intake": "done"` and `"impact_analysis": "done"` as this piece's own step keys
   (D1 — open steps map).
9. **Initialize `_notes.md`** with a short intake summary, a one-line impact-analysis takeaway
   (complexity signal + whether a blocker/related work was found), and the immediate next action.

## Output

Report: the folder path, the ticket title, whether a diagram was found (→ `bcs-flowchart-check`), any
related tickets, the `impact-analysis.md` headline (complexity signal, repos involved, any
blocker/related work found), and the suggested next step (`/prd` or `/run` over this folder). Do
**not** start requirements/design analysis here — that is `/prd`'s and `/spectech`'s job; the
impact analysis reports findings, not proposed solutions.

## Guardrails

- Read-only against Jira; never transition or comment on the issue here.
- Never write tokens/secrets into the folder.
- If the ticket cannot be fetched, stop-gate — do not fabricate ticket content.
- Standalone piece: do **not** assume this ran — `/run`'s Jira-key handling (see `run-pipeline`'s
  Ticket-folder resolution) does its own lightweight scaffold-or-find and does **not** call this
  agent automatically (FR-10).
