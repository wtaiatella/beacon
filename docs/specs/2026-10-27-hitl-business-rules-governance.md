# Spec / Framework Improvement: Enforcing Human-in-the-Loop (HITL) Stop-Gates for Business Rule Ambiguities in SDD Pipelines

- **Date:** 2026-10-27
- **Status:** Proposed / Framework Governance Update
- **Target Framework:** Beacon Spec-Driven Development (SDD)
- **Originating Ticket / Case Study:** [APC-24](https://wtaiatella.atlassian.net/browse/APC-24) (*Job Queue Priority & Orphan Retention Policy*)
- **Language Standard:** English

---

## 1. Executive Summary & Problem Statement

During autonomous end-to-end SDD pipeline executions (`/run`), AI agents operate with high technical independence across pre-planning, requirements engineering, technical design, implementation, and QA.

However, a critical governance gap was identified during the execution of real-world ticket **APC-24**:

* **The Autonomy vs. Alignment Hazard:** When user stories or intake tickets contain underspecified business rules or ambiguous functional requirements (e.g., *"periodic purge routine"*, *"discard policy"*), technical agents tend to infer a reasonable technical default (e.g., coupling a 24h timer to an existing background worker) rather than pausing to confirm the business intent with the human product owner.
* **Cascading Risk:** If an agent's inferred assumption diverges from actual product vision or operational requirements (e.g., choosing an in-process worker timer vs. an external scheduled cronjob, or choosing physical hard-delete vs. soft-delete archiving), significant rework is triggered downstream after code has already been generated, tested, and reviewed.

**Core Principle:** *Agents must be autonomous in technical implementation, but never autonomous in guessing product business rules.*

---

## 2. Identified Ambiguities (Case Study APC-24)

| Finding / Ambiguity                            | What Occurred in Pipeline                                                                                                                                       | Potential Risk                                                                                   | Correct Governance Reaction                                                                                    |
| :--------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------- |
| **Physical Hard Delete vs. Soft Delete** | Ticket used terms *"descarte de vagas"* and *"expurgar vagas"*. Database schema had no soft-delete column, but relational tables had `onDelete: Cascade`. | Unchecked physical deletion could accidentally purge candidate interactions (applications, CVs). | Agent must verify if business requires physical purge or logical archiving, confirming interaction safeguards. |
| **Execution Trigger & Cadence**          | Ticket specified *"rotina periódica"* without stating frequency or trigger mechanism.                                                                        | Agent autonomously chose a 24h background timer in the scraper worker.                           | Agent must present options (24h timer, cron route, CLI job) to the human operator for business sign-off.       |

---

## 3. The 2 Mandatory Injection Points for HITL Stop-Gates

To eliminate unvalidated assumptions, the Beacon SDD workflow mandates **two explicit injection points** where Human-in-the-Loop (HITL) interactions must halt execution:

```
[Intake Ticket / Idea]
         │
         ▼
┌────────────────────────────────────────────────────────┐
│ 1. PRD Discovery & Requirements Phase                  │
│    (prd-discovery / generate-prd)                      │
│    🔎 Ambiguity Hunting: Scan for missing business rules│
│    🛑 HITL STOP-GATE: Emit QUESTION: / ASK_USER        │
└────────────────────────────────────────────────────────┘
         │ (Human Operator confirms decision)
         ▼
┌────────────────────────────────────────────────────────┐
│ Pre-Plan Synthesis & Review Gate                       │
│ (pre-plan-reviewer & Task(scrum))                      │
│ 🛑 HITL STOP-GATE: Gate verifies zero blind assumptions│
│    Outcome: PROCEED only if all business rules resolved│
└────────────────────────────────────────────────────────┘
         │
         ▼
[Technical Design: spectech.md ➔ Implementation: tasks.md]
```

### Point 1: Phase A — PRD Discovery (`prd-discovery` / `generate-prd`)

* **Role & Responsibility:** Proactive ambiguity hunting prior to drafting `prd.md`.
* **Execution Rule:**
  1. The PRD persona must inspect ticket text specifically for underdefined business behaviors (trigger frequency, deletion type, data retention limits, edge-case fallbacks).
  2. If any ambiguity is discovered, the persona **must not guess or choose a default**.
  3. It must emit an explicit `QUESTION:` / `ASK_USER` prompt presenting concise options (e.g., multiple choice) to the user.
* **Artifact Output:** The resolved decision must be explicitly recorded in `prd.md` under `### 1.x Business Decisions & Confirmed Assumptions`.

### Point 2: Pre-Plan Review & Scrum Gate (`pre-plan-reviewer` / `scrum`)

* **Role & Responsibility:** Gatekeeper review before technical specification begins.
* **Execution Rule:**
  1. The `pre-plan-reviewer` audits the merged specialist brief. If it detects that a business rule was populated by an agent assumption without human confirmation, it must flag the brief as **INCOMPLETE**.
  2. The `Task(scrum)` gatekeeper must evaluate this finding. If unresolved business questions exist, `Task(scrum)` **must emit `ASK_USER` or `REWORK`**, strictly preventing transition to `Task(spectech)`.
  3. Technical architecture (`spectech.md`) must never commence on top of unverified business foundations.

---

## 4. Control Documents & Audit Protocol

Every HITL event must be logged transparently in the ticket working folder:

### A. Machine State (`_state.json`)

When a HITL stop-gate is triggered:

```json
{
  "current_step": "prd_discovery",
  "steps": {
    "ticket_intake": "done",
    "pre_plan": "in_progress",
    "prd": "blocked"
  },
  "blocked_reason": "waiting_user_business_clarification",
  "pending_question": "Should the job cleanup routine execute via a 24h background worker timer or an external cron route?"
}
```

### B. Human-Readable Audit Log (`_notes.md`)

Append-only log entry recording the stop and resumption:

```markdown
### 2026-10-27T22:15:00Z — [STOP-GATE HITL] Business Rule Clarification
- **Acting Persona:** prd-discovery / pre-plan-reviewer
- **Missing Rule:** Execution cadence and trigger mechanism for job cleanup routine.
- **Question Posed to User:**
  1. Background worker timer (every 24h on application boot).
  2. Dedicated API route for external cron scheduler (e.g. Vercel Cron / GitHub Actions).
  3. Manual CLI maintenance script.
- **Status:** Paused awaiting operator input.

### 2026-10-27T22:18:00Z — [HITL RESOLVED] Operator Decision
- **Operator Decision:** Option 1 (24h background timer in scraper worker).
- **Recorded In:** prd.md (Section 3.4) and spectech.md (Decision D-3).
- **Resume Point:** Task(spectech) unblocked.
```

### C. Requirements Document (`prd.md`)

Every PRD must maintain an explicit section:

```markdown
## Assumptions & Validated Business Decisions
- **AD-01 (Clean-up Cadence):** Confirmed by PO to execute once every 24 hours on worker startup.
- **AD-02 (Deletion Type):** Confirmed physical hard-delete of records, with strict relational checks (`none: {}`) protecting any job with candidate interactions.
```

---

## 5. Story Authoring Guidelines for Jira Intake

To prevent ambiguities at the source, workspace guidelines must advise backlog authors:

1. **Unambiguous Vocabulary:**
   * Use **"Hard delete (physical removal from database)"** instead of generic *"discard"* or *"purge"*.
   * Use **"Soft delete / Archive (status flag or deletedAt timestamp)"** when records should remain in DB.
2. **Explicit Cadence & Triggers:**
   * Specify operational triggers (e.g., *"Daily background routine"* or *"Triggered on user login"*).
3. **Language Standard:**
   * Authored in **English** with standard international engineering terminology.

---

## 6. Action Items for Framework Maintenance

1. [ ] **Update `agentic/agents/prd.md`**: Inject ambiguity detection prompt and mandate `QUESTION:` for missing business rules.
2. [ ] **Update `agentic/agents/pre-plan-reviewer.md`**: Add validation rule penalizing unconfirmed agent assumptions in the brief.
3. [ ] **Update `agentic/skills/run-pipeline/SKILL.md`**: Document the two HITL gates and the `_state.json` blocked state convention.
4. [ ] **Sync Workspaces**: Propagate framework updates to consumer workspaces via `scripts/upgrade.sh`.
