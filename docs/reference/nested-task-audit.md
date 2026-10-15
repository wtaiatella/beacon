# Nested Task / subagent audit — Phase 1 inventory + Phase 2 remediation plan

**Spec:** `docs/specs/2026-04-10-road-36-nested-task-subagent-audit-spec.md`  
**Scope:** Phase 1 — inventory and classification. Phase 2 — **remediation plan** (recommended wording; **no** agent-file edits here — Phase 3).  
**Scan date:** 2026-04-10  
**Remediation plan added:** 2026-04-10  

## Method

- Ripgrep over `.cursor/agents/**/*.md` for: `Task(`, delegate/sub-delegate language (case variants), `parallel` near agent names, `codebase-explorer`, `spec-validator`, `security-scanner`, and `mcp-*` specialist names.
- Ripgrep over `.cursor/rules/*.mdc` for the same patterns (optional extension per spec).

## Categories

| Category | Meaning |
|----------|---------|
| **orchestrator-doc** | Text describes what the **`/run` main session** schedules or awaits (`Task(...)`, waves, gates). Not an instruction for a persona to spawn another `Task`. |
| **readonly-helper** | Read-only specialist or tool (validators, explorer **as** readonly scout) referenced without implying hidden orchestration—or explicit “orchestrator runs this.” |
| **nested-risk** | Wording that can be read as **the persona** delegating to another named agent (`Sub-delegate`, `Delegate to …`, `Launch … concurrently` as sub-steps) without a clear **`REQUEST_MAIN:`** / main-session handoff—may imply a second orchestration layer. |

## Risk column (subagent posture)

| Risk | Meaning |
|------|---------|
| **read-only** | Agent YAML or body states readonly / no spec or product writes (typical: `*-reviewer`, `pre-plan-triage`, `mcp-*`, `spec-validator`, `security-scanner`, `codebase-explorer`). |
| **write-capable** | Persona may edit specs, code, or infra (e.g. `plan`, `dev`, `fix`, `do`, `kb`). |
| **orchestrator-only (doc)** | Not a persona posture—router/skill text about the main session. |

---

## Classification table (hits and file-level notes)

**Snapshot:** Rows below reflect the **2026-04-10** scan; refresh **`qa.md`** / **`fix.md`** (and related) rows after agent edits so the table stays aligned with current files.

| File | Pattern snippet | Category | Risk | Notes |
|------|-----------------|----------|------|-------|
| `pre-plan-triage.md` | YAML `description`: "…before Task(plan)—this agent does not invoke Task or MCP tools." | orchestrator-doc | read-only | **Orchestrator-only documentation:** triage outputs **wave lists** so the **main session** runs `Task(mcp-glean)`, `Task(mcp-arc)`, etc. Agent explicitly **does not** invoke `Task` or MCP. |
| `pre-plan-triage.md` | "so the orchestrator can run **`Task(mcp-arc)`** in **Wave 1**" | orchestrator-doc | read-only | Same: **narrates** orchestrator scheduling, not self-delegation. |
| `pre-plan-triage.md` | "**Wave 1** runs **`Task(mcp-glean)`** and **`Task(mcp-arc)`** in parallel … **Wave 2** runs **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`** …" | orchestrator-doc | read-only | Staged-wave **contract** for the orchestrator; triage agent remains reasoning-only. |
| `mcp-arc.md` | "bounded brief merged into **`Pre-plan context:`** for **`Task(plan)`**" | orchestrator-doc | read-only | **Orchestrator-only:** positions pre-plan ARC as input to **`Task(plan)`**; **ARC lane B** (in-session MCP) applies to **`/plan`** (and **`/kb`** where applicable) only—**not** **`/dev`** or **`/fix`** after **ROAD-47** (`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`). **`/dev`** and **`/fix`** use **`REQUEST_MAIN: ARC <query>`** and orchestrator **`Task(mcp-arc)`**. Does **not** tell `mcp-arc` to call `Task(...)`. |
| `plan.md` | "`Task(pre-plan-triage)` → parallel `Task(mcp-*)` … **`Task(plan)`**" | orchestrator-doc | write-capable | Documents **pre-plan** already run by main session; tells `/plan` not to duplicate MCP gather. |
| `plan.md` | "**Sub-delegates:** `codebase-explorer` (parallel …)" | nested-risk | write-capable | Instructs **plan** to treat explorer as sub-delegate when KB/ARC insufficient—**Phase 2** remediation candidate (flatten vs `REQUEST_MAIN:`). |
| `plan.md` | "**Delegate to** `codebase-explorer` in **parallel**" | nested-risk | write-capable | Same. |
| `kb.md` | "**Sub-delegates:** `codebase-explorer` …" / "**Delegate to** `codebase-explorer`" | nested-risk | write-capable | **Phase 2** remediation candidate. |
| `fix.md` | "**Sub-delegates:** `codebase-explorer` … **delegate** to **codebase-explorer**" | nested-risk | write-capable | **Phase 2** remediation candidate. |
| `qa.md` | "**do not** invoke **`Task(...)`** on other agents yourself" | orchestrator-doc | write-capable | Explicit **anti-nested-Task** guardrail for QA. |
| `qa.md` | "**Sub-delegates:** `spec-validator` (parallel), `security-scanner` (parallel)" | nested-risk | write-capable | Contrasts with line 15: implies QA **launches** validators—**Phase 2** to reconcile with "orchestrator delegates validators" vs subagent tools. |
| `qa.md` | "**Parallel sub-delegation:** Launch **`spec-validator`** and **`security-scanner`** concurrently" | nested-risk | write-capable | Same. |
| `qa.md` | "`Task(scrum)` … `Task(summary)`" (orchestrator next steps) | orchestrator-doc | write-capable | Documents **main-session** sequence after QA output. |
| `dev.md` | "`Task(scrum)` **PROCEED**", Proposed completions | orchestrator-doc | write-capable | Orchestrated delegation rules; no `Task` to other personas. |
| `sre.md` | same pattern | orchestrator-doc | write-capable | Same. |
| `data.md` | same pattern | orchestrator-doc | write-capable | Same. |
| `scrum.md` | "`Task(plan)`", "`Task(qa)`", "`Task(summary)`" authorization narrative | orchestrator-doc | write-capable | Gate copy for **`/run`**; not subagent chaining. |
| `do.md` | "Task unclear" (English word only) | — | write-capable | **No** literal `Task(` or delegation idiom; scoring: not a nested-Task hit. |
| `plan-reviewer.md` | "Task clarity" (scoring factor) | — | read-only | **False positive** for delegation—spec task quality, not `Task()`. |

### Agents with no `Task(` / Sub-delegate / Delegate-to / parallel specialist lines

These files were reviewed; they do **not** contain the scanned delegation patterns in substantive form (name-only or unrelated “task” wording excluded):

| File | Risk (typical) | Notes |
|------|----------------|-------|
| `codebase-explorer.md` | read-only | Defines explorer; no self-delegation language. |
| `spec-validator.md` | read-only | Validator definition only. |
| `security-scanner.md` | read-only | Scanner definition only. |
| `dev-reviewer.md` | read-only | No `Task(` / sub-delegate lines. |
| `sre-reviewer.md` | read-only | Same. |
| `data-reviewer.md` | read-only | Same. |
| `mcp-glean.md` | read-only | “Orchestrator” in description; no literal `Task(`. |
| `mcp-jira.md` | read-only | Same. |
| `mcp-confluence.md` | read-only | Pointers to `mcp-jira`; no `Task(`. |
| `mcp-gitlab.md` | read-only | No `Task(` in scan. |
| `summary.md` | write-capable (docs output) | Orchestrated `/run` context; no nested `Task` instructions. |

---

## `.cursor/rules/*.mdc` (optional scan)

| File | Pattern snippet | Category | Notes |
|------|-----------------|----------|-------|
| `00-workspace-router.mdc` | `Task(pre-plan-triage)`, `Task(mcp-*)`, `Task(plan)`, `Task(dev)`, … | orchestrator-doc | Router defines **main-session** orchestration; explicitly says pre-plan MCP specialists are **not** nested inside `Task(plan)`. |
| `run-pipeline-trigger.mdc` | `Task(subagent_type="plan"\|"dev"\|…)` | orchestrator-doc | Main session delegates per skill—no persona nesting. |
| `git-gitlab-mutations.mdc` | (no `Task(` hits) | — | Out of scope for nested-Task narrative. |

---

## Explicit finding: `pre-plan-triage.md` and `mcp-arc.md` vs `Task(mcp-*)`

Both files use **`Task(mcp-*)`** / **`Task(plan)`** language as **documentation of orchestrator scheduling**, not as instructions for the triage or ARC specialist to invoke **`Task`** themselves.

| File | Evidence |
|------|----------|
| **pre-plan-triage.md** | YAML description: "this agent does not invoke Task or MCP tools." Role: "You **do not** call **`Task`**, **Glean**, **Atlassian**, or **GitLab** tools—the **main session** performs those delegations." Staged waves section titles the contract "**orchestrator contract**" and lists which **`Task(...)`** calls the orchestrator makes after triage output. |
| **mcp-arc.md** | Pre-plan role: brief for **`Pre-plan context:`** → **`Task(plan)`**. Toolbox is ARC MCP tools only; no `Task` to other agents. |

**Conclusion:** Aligns with **flat** pre-plan: **only the main session** schedules `Task(mcp-glean)`, `Task(mcp-arc)`, Wave 2 specialists, then `Task(plan)`.

---

## Summary counts

- **Files in `.cursor/agents`:** 24 `.md` files scanned.
- **Files with `Task(` in body:** `data.md`, `dev.md`, `mcp-arc.md`, `plan.md`, `pre-plan-triage.md`, `qa.md`, `scrum.md`, `sre.md` (mostly orchestrator-doc or anti-nested guidance).
- **Files with Sub-delegate / Delegate-to / parallel specialist chains:** `fix.md`, `kb.md`, `plan.md`, `qa.md` (primary **nested-risk** set for Phase 2).
- **Highest-signal nested-risk:** `plan.md`, `kb.md`, `fix.md` (codebase-explorer); `qa.md` (spec-validator + security-scanner).

---

## Phase 2 remediation plan (draft wording / decisions — Phase 3 applies edits)

This section records **recommended replacement text themes** per agent file. It **does not** edit `.cursor/agents/*.md` (that is **Phase 3**).

### Decision: `codebase-explorer` — main session vs inline tools vs `REQUEST_MAIN:`

**Chosen story (consistent across plan / kb / fix):**

| Context | Discovery path |
|--------|----------------|
| **Orchestrated `/run`** | The **main session** may already have run **`Task(codebase-explorer)`** or supplied **`Pre-plan context:`**. The persona (**`Task(plan)`**, etc.) uses **inline** **Read**, **Grep**, **Glob**, **SemanticSearch** (and ARC/KB per existing order) for gaps. If a **parallel read-only scout pass** is still required and was **not** scheduled by the orchestrator, the persona **does not** invoke **`Task(codebase-explorer)`** itself — it returns **`REQUEST_MAIN:`** with directory list and rationale so the **main session** can schedule **`Task(codebase-explorer)`** on the next turn. |
| **Standalone** `/plan`, `/kb`, `/fix` (user-invoked) | **Prefer inline** tools for orientation (same as above). If a dedicated explorer pass is still needed, **ask the user** to run **`/codebase-explorer`** with the target directory (or equivalent) **before** continuing, or proceed with inline search and document uncertainty — **do not** describe **invoking** **`Task(codebase-explorer)`** yourself as a sub-step. |

**Rationale:** Preserves a **single orchestration layer** for literal **`Task(...)`** scheduling; avoids “persona delegates to explorer in parallel” language that implies nested orchestration. Aligns with spec **Open Question 1** toward **main-session-owned** explorer scheduling with **`REQUEST_MAIN:`** when the persona cannot proceed without it; inline tools are the default when explorer is not scheduled.

---

### Per-file recommended wording (Phase 3 targets)

#### `plan.md`

- **Remove or replace** toolbox lines: **“Sub-delegates:** `codebase-explorer` …”** and workflow **“Delegate to `codebase-explorer` in parallel”** with the **Decision** table above.
- **Workflow step 5** (KB missing): say **use Read / Grep / SemanticSearch** (and optional user **`/codebase-explorer`** when standalone) **or** **`REQUEST_MAIN:`** under orchestration — **not** “delegate to codebase-explorer in parallel” as a persona-owned **`Task`**.
- **Keep** pre-plan bullets that describe **main-session** **`Task(pre-plan-triage)`** / **`Task(mcp-*)`** — those remain **orchestrator-doc**.

#### `kb.md`

- **Replace** **“Sub-delegates:** `codebase-explorer`”** and workflow **“Delegate to `codebase-explorer`”** with: initial discovery via **inline** repo tools; optional **user-invoked** **`/codebase-explorer`** per target dir when the user wants a scout pass first; **no** persona-spawned **`Task(codebase-explorer)`** wording.

#### `fix.md`

- **Replace** **“Sub-delegates:** `codebase-explorer`”** and **“delegate to codebase-explorer”** in **Orient** with: unfamiliar codebase → **Read / Grep / SemanticSearch** first; **or** ask the user to run **`/codebase-explorer`** for layout; under orchestrated **`/fix`**, **`REQUEST_MAIN:`** if the main session must schedule explorer — same pattern as **plan**.

#### `qa.md` — reconcile validators with “do not invoke `Task(...)`”

**Tension:** Lines 15–16 forbid the QA persona from invoking **`Task(...)`** on other agents; lines 29–37 describe **Sub-delegates** and **“Parallel sub-delegation: Launch `spec-validator` and `security-scanner` concurrently.”**

**Chosen reconciliation (orchestrator-delegates-validators story — ROAD-50 aligned):**

- **`Task(spec-validator)`** / **`Task(security-scanner)`** in orchestrated **`/run`** = **main session only**: **QA prep wave** (**`run-pipeline`** **§ 7.0** / **ROAD-50**) runs both **in parallel immediately before** **`Task(qa)`**, persists reports under **`<ticket-folder>/_run/scanners/`**, and injects paths/summaries into the **`Task(qa)`** prompt. Personas **do not** schedule these **`Task(...)`** calls.
- **Inside `Task(qa)`:** the QA persona **does not** invoke **`Task(spec-validator)`** or **`Task(security-scanner)`**; it **uses** the **pre-run artifacts** (and optional **`Read`** of session files) that the orchestrator already produced. Standalone user **`/qa`** (no **`/run`**) may still invoke **`/spec-validator`** / **`/security-scanner`** manually — that is **outside** this orchestrator scheduling story.
- **Replace** headings that say **“Sub-delegates”** / **“Parallel sub-delegation”** with neutral labels such as **“Pre-run artifacts (orchestrator)”** or **“Readonly specialists (standalone `/qa` only)”** so **`/run`** is **not** read as the QA persona spawning **`Task(spec-validator)`** / **`Task(security-scanner)`** itself.
- **Workflow step 4 (orchestrated `/run`):** e.g. **“Use spec-validator and security-scanner outputs from **`artifacts/scanners/`** (orchestrator QA prep wave);** if missing, **note** confidence impact and **do not** spawn **`Task(...)`** yourself.”

#### `dev.md`, `sre.md`, `data.md`, `qa.md`, `fix.md` — Phase 2 confirmation + ROAD-47 enterprise MCP

| File | Phase 2 note |
|------|----------------|
| **`dev.md`** | **Clean** for nested-**`Task`** delegation: all **`Task(`** hits are **orchestration-doc** (**`Task(scrum)`** **PROCEED**, **Proposed completions**). No **Sub-delegate** / **Delegate to** another persona. **No mandatory** Phase 3 change for nested-**`Task`** policy beyond optional cross-link. |
| **`sre.md`** | **Same** as **dev.md**. |
| **`data.md`** | **Same** as **dev.md**. |
| **`qa.md`** | Same nested-**`Task`** posture; **ROAD-47** removes optional direct enterprise MCP from the toolbox—use **`REQUEST_MAIN: <Glean|Jira|Confluence|GitLab|ARC> <query>`** for orchestrator **`Task(mcp-*)`**. |
| **`fix.md`** | Same; **ROAD-47** removes in-session ARC/GitLab/Glean/Jira optional calls—**`REQUEST_MAIN`** for specialists; **`REQUEST_MAIN`** for **`Task(codebase-explorer)`** remains a separate handoff (see **Toolbox**). |

**ROAD-47:** Implementation-tier agents must **not** document optional direct enterprise MCP; authoritative spec **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`**. **`00-workspace-router.mdc`** / **`run-pipeline`** lane-B updates land in that spec’s Phase 2.

---

### Phase 2 reminder (ROAD-47 router / skill alignment)

Cross-links in **`00-workspace-router.mdc`** and **`run-pipeline` skill** for ARC lane B and mid-run **`REQUEST_MAIN`** — spec **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`** **Phase 2** (orchestrator and workspace rules). Broader **`*-reviewer`** Optional MCP scrub is that spec’s **Phase 3**.

**Phased implementation:** Domain isolation for **`Task(dev|sre|data)`** is specified in **`docs/specs/2026-04-10-road-38-phased-implementation-domain-isolation-spec.md`**; authoritative behavior remains **`.cursor/skills/run-pipeline/SKILL.md`** § 5–6.

---

## Phase 4 verification (re-scan)

**Date:** 2026-04-10  
**Method:** Ripgrep over **`.cursor/agents/**/*.md`** for literal **`Task(`** and for delegation idioms (**Sub-delegate**, **Delegate to**, **invoke** + **`Task`**).

### Result: pass

| Finding | Detail |
|--------|--------|
| **Personas invoking `Task(...)` on another agent without escalation** | **None found.** Every **`Task(`** hit is either (a) **orchestrator-only narration** (what the **`/run`** main session schedules or awaits — including **pre-plan-triage** Wave 1/2 **`Task(mcp-*)`** contract text), (b) an explicit **“do not invoke `Task(...)` yourself”** / **`REQUEST_MAIN:`** guardrail, or (c) **gate copy** in **scrum** / **orchestrated delegation** bullets (**`Task(scrum)`** **PROCEED**, **Proposed completions**). |
| **pre-plan-triage / mcp-arc** | Still **orchestrator-doc** only: triage YAML states the agent **does not** invoke **`Task`** or MCP tools; wave sections describe what the **main session** runs after triage output. |
| **Regression phrases** (historical nested-risk) | No **`Sub-delegate`**, **`Parallel sub-delegation`**, or **“Delegate to `codebase-explorer`”** lines remain under **`.cursor/agents/`** — remediation from Phases 2–3 holds. |

**Optional tooling:** **`scripts/tools/check-nested-task-docs.sh`** (warnings-only, always **exit 0**) greps agent files for those regression phrases; **`lint-workspace-agents.sh`** (agent frontmatter validation) does **not** cover nested-**`Task`** semantics — the nested check is separate and non-blocking in **`docs-check`** (see **`.gitlab-ci.yml`**).

---

## Maintainers

- **Orchestration source of truth:** **`.cursor/skills/run-pipeline/SKILL.md`** — main-session **`Task`** sequencing, nested-**`Task`** anti-patterns, implementation payload construction (§ 5), pre-plan waves, **`--resume`**, and Finish policy. This file (**`nested-task-audit.md`**) is the **inventory + remediation narrative** for agent/router wording; it does **not** override the skill.
- **ARC lane B vs ROAD-47:** **`/dev`** and **`/fix`** are **not** in-session ARC MCP actors; they escalate via **`REQUEST_MAIN: ARC <query>`** and orchestrator **`Task(mcp-arc)`**. Lane B (in-session ARC where still documented) applies to **`/plan`** (and **`/kb`** if applicable) per **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`** and aligned router/skill edits.
- **Specs:** **`docs/specs/2026-04-10-road-36-nested-task-subagent-audit-spec.md`**; **`docs/specs/2026-04-10-road-38-phased-implementation-domain-isolation-spec.md`** (implementation segment audit).
