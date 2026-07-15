---
name: generate-spectech
description: "Technical specification document template and generation instructions for the /spectech persona. Produces spectech.md with architecture, APIs, data models, and testing strategy — right-sized to the change via spec profiles."
---

# Generate Spectech

## When to Use

- Creating technical specification from approved PRD
- Updating spectech.md with design changes
- Documenting architecture and contracts
- Any time `/spectech` needs to produce or modify spectech.md file

Output format is **normative**: within the chosen profile, follow section order exactly.

## Prerequisite

- **Must read prd.md first** — validates that /prd has completed
- If prd.md missing, agent asks user to run `/prd` first
- Cannot skip order enforcement

## Output Location and Naming

- **Directory:** `docs/specs/{slug}/` (same folder as prd.md)
- **Filename:** `spectech.md` (always this name)

## Spec Profiles (Right-Sizing) — choose BEFORE writing

**Match the spec's depth to the change. Over-building a spec for a trivial change is a defect:**
it wastes effort and confuses downstream execution. Classify the change, then include only the
sections that profile calls for. **Omit non-applicable sections entirely — never leave "N/A" stubs.**

Pick the smallest profile that fits:

- **Lean** — localized change, no new dependency or architectural pattern, no schema change, no
  security/performance/migration concern. Sections: Header, Title, Goals/Non-Goals,
  **Technical Decisions** (brief), **Testing Strategy**, **Risks**, **Clarifications & Assumptions**.
- **Standard** — a typical feature. Lean **plus**: Architecture, Component & File Map,
  Dependencies, API Contracts *(if external surface)*, Data Models *(if data involved)*,
  Error Handling, Security, Observability, Performance *(if relevant)*, Implementation Notes.
- **Full** — **any** of these triggers (mirrors when a heavyweight design is actually warranted):
  cross-cutting change (multiple services/modules) · a new architectural pattern · a new external
  dependency · significant data-model changes · security/performance-critical · migration
  complexity. Standard **plus**: Migration & Rollback, Complexity Tracking, and deeper
  boundary/coupling analysis in Architecture.

Record the chosen profile in the header (`profile: lean|standard|full`) and in
`_state.json.spectech_profile` (see the `ticket-workflow` skill — the only control-file
convention).
When in doubt, start smaller — you can deepen a section, but don't manufacture sections.

## Spectech Template (section order; include per profile)

### 1. Header with Metadata *(all)*

```markdown
---
name: {slug}
last-updated: {YYYY-MM-DD}
status: draft
workflow: spectech-done
prd-ref: prd.md
profile: standard   # lean | standard | full
---
```

- `workflow`: spectech-done (set by /spectech)
- `prd-ref`: reference to input PRD
- `profile`: the right-sizing profile chosen above

### 2. Title (H1) *(all)*

Technical design title (same as PRD, prefixed with "Technical Design: ")

### 3. ## Goals / Non-Goals *(all)*

- **Goals:** what this design achieves technically (trace back to the PRD goals/ACs).
- **Non-Goals:** technical scope explicitly excluded, so the design stays bounded
  (e.g., "single-region only — no multi-region failover", "no real-time sync in this iteration").

### 4. ## Architecture *(Standard+; Lean: 2–3 sentences of approach, no diagram)*

- Diagram (Mermaid or description) showing components, data flow, integration points, external
  service connections.
- Prose explaining architecture decisions and patterns used.
- **Boundaries & coupling (Full):** for each component state what it does, its public interface,
  what it depends on, and what state/data it owns (see Component & File Map). Prefer **narrow,
  vendor-agnostic interfaces** and communication via dedicated DTOs / anti-corruption layers over
  passing rich internal or vendor SDK types across boundaries — so an implementation can be
  swapped without breaking consumers.

### 5. ## Component & File Map *(Standard+)*

Lock decomposition **here**, before `/tasks`. List which files are created/modified and each
one's **single responsibility**. Split by responsibility, not by technical layer; files that
change together live together.

| File | Create/Modify | Responsibility (one) | Public interface | Depends on |
|------|---------------|----------------------|------------------|------------|
| `domain/trial.ts` | Create | Trial calc & validation (pure) | `calcExpiration()`, `isExpired()` | — |
| `service/trial-service.ts` | Create | Create/fetch trial use cases | `createTrial()`, `getStatus()` | trial, repo |
| `persistence/trial-repository.ts` | Create | Trial CRUD | `save()`, `findById()` | ORM |

### 6. ## Technical Decisions (ADR-lite) *(all; brief for Lean)*

For each significant choice, capture the reasoning — not just the tech name:

- **Decision:** Batch reconciliation with Stripe every hour (not real-time webhooks).
  - **Rationale:** simpler; no public webhook endpoint to secure; hourly drift acceptable per SC-2.
  - **Alternatives considered:** real-time webhooks (rejected — added attack surface + infra);
    poll-on-read (rejected — read latency).
  - **Trade-off:** up to ~1h status staleness.

### 7. ## Dependencies & Versions *(Standard+; include when new/changed deps)*

Be explicit about what already exists vs. what is added:

| Component | Library/Service | Version | Purpose | New? |
|-----------|-----------------|---------|---------|------|
| Payment | Stripe API | v1 | Process payments | existing |
| Database | PostgreSQL | 14+ | Data persistence | existing |
| Queue | Redis | 7.x | Background jobs | **new** |

### 8. ## API Contracts *(include when there is an external interface)*

**Endpoint: POST /api/trials**
```
Request:  { "email": "user@example.com", "duration_days": 14 }
Response: { "trial_id": "tr_xxxxx", "expires_at": "2026-07-25T00:00:00Z", "status": "active" }
Errors:   400 Invalid email · 409 Trial already exists for this email
```

Or reference an OpenAPI/Swagger file in attachments. Skip this section for purely internal work.

### 9. ## Data Models / Database Schema *(include when data is involved)*

```sql
CREATE TABLE trials (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  email VARCHAR(255) NOT NULL,
  started_at TIMESTAMP,
  expires_at TIMESTAMP,
  status ENUM('active', 'expired', 'cancelled'),
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

Or JSON schema for document databases.

### 10. ## Error Handling Strategy *(Standard+)*

- Invalid input → 400 Bad Request with specific field errors
- Duplicate trial → 409 Conflict
- Service unavailable → 503 with retry-after
- Database errors → 500 (log details, return generic message)

Align with existing error classes/conventions found in the codebase analysis.

### 11. ## Testing Strategy *(all)*

Testing approach by level, aligned with the project's detected frameworks/patterns:

**Unit / Integration / E2E** — what each covers (trial calc & validation; creation end-to-end with
DB; signup → active → notification flow).

**Verification mapping (no separate file):** for each PRD acceptance criterion, name how it is
verified — test type + a concrete check. This is what QA and `/tasks` consume:

| PRD criterion | Verified by |
|---------------|-------------|
| AC-1 trial activates < 30s | integration test asserting activation + timing |
| AC-3 reminder sent once at T-3d | unit test on scheduler + integration on send-once idempotency |

### 12. ## Security Requirements *(Standard+; expand for Full)*

- PII encrypted at rest; endpoints require authentication
- Rate limiting on trial creation (1 per email / 24h)
- No card stored (Stripe handles); GDPR: trials deletable

### 13. ## Performance Requirements *(include when relevant)*

- Trial creation < 200ms · status lookup < 50ms · notification within 24h

### 14. ## Observability / Logging *(Standard+)*

- **Metrics:** trial_creation_count, trial_expiration_count, notification_delivery_latency
- **Logging:** creation/deletion events, notification sends, integration failures — structured
- **Alerts:** creation failures > 5%, delivery latency > 1h, Stripe API errors

### 15. ## Risks & Mitigations *(all)*

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Email not sent | User unaware of expiration | Retry queue + manual check UI |
| Stripe sync failure | Status out of sync | Reconciliation job every hour |

### 16. ## Migration & Rollback *(Full; or whenever the change touches live data or deploy)*

- **Deploy:** step ordering; backward-compatibility plan (expand/contract for schema changes).
- **Data migration:** forward and backward scripts (if schema changes).
- **Rollback:** how to revert safely; feature-flag / kill-switch if applicable.

### 17. ## Complexity Tracking *(Full; include ONLY if the design introduces new complexity)*

**Default to fewer moving parts.** Reuse or flatten before adding a new module/service/dependency/
boundary. Justify each addition:

| Added complexity | Why needed | Simpler alternative rejected because |
|------------------|-----------|--------------------------------------|
| New Redis queue | async notification retries | in-process retry rejected — lost on restart |

Split a boundary only when **several** of these hold: different language · different rate of
change · independent scale/SLO · separate transaction boundary · distinct ownership · a concrete
pain signal **today** (not hypothetical).

### 18. ## Clarifications & Assumptions *(all)* — replaces "Open Technical Questions"

- Mark genuinely **blocking** unknowns inline as `[NEEDS CLARIFICATION: <question>]`
  (budget **3**; priority: correctness/security > data integrity > architecture > minor detail).
  These **MUST be zero at hand-off** — resolved via the `/spectech` clarification loop, then
  recorded here as decisions (or folded into Technical Decisions).
- **Assumptions:** technical defaults chosen when the PRD/codebase was silent (e.g., "expiration
  computed in UTC internally").
- **Deferred (non-blocking):** technical questions intentionally postponed, with rationale — never
  park correctness/security-affecting decisions here.

### 19. ## Implementation Notes *(Standard+)*

- Trial expiration uses UTC internally
- Migrations backward compatible
- Idempotency for notification endpoints (retries)

---

## Self-Review Before Handoff

Run this as an actual review with fresh eyes (not just a box-tick):

- [ ] **Right-sized:** profile matches the change; no manufactured sections, no missing needed ones
- [ ] **No placeholders:** zero `[NEEDS CLARIFICATION]`, no "TBD/TODO", no vague "add appropriate
      error handling"
- [ ] **Internal consistency:** names/types referenced in one section are defined and spelled the
      same everywhere (a method called `clearLayers()` in one place and `clearFullLayers()` in
      another is a bug)
- [ ] **Architecture ↔ map match:** components in Architecture appear in the Component & File Map
- [ ] **Decisions justified:** each significant choice has rationale + alternatives
- [ ] **PRD traceability:** every PRD acceptance criterion is addressable and has a Verification entry
- [ ] **Testing strategy** covers the levels appropriate to the change
- [ ] File saved to `docs/specs/{slug}/spectech.md`; `_state.json.steps.spectech` updated to
      `"done"`, `_state.json.spectech_profile` set to the chosen profile, and a matching
      `_notes.md` entry appended — per the `ticket-workflow` skill (the only control-file
      convention; no other metadata file is created)

---

## Notes

- **Focus on HOW, not WHAT** — WHAT is in PRD; HOW is here
- **Right-size ruthlessly (YAGNI)** — prefer fewer boundaries/dependencies until real pain appears;
  "flat is often better" than premature fragmentation
- **Hard to test = hard to use** — if a component can only be tested by mocking everything, the
  coupling is wrong; prefer dependency injection and narrow interfaces
- **Be technical but clear** — explain decisions, not just list tech
- **Reuse existing patterns** — align with the frameworks/architecture found in codebase analysis;
  don't invent new testing or architectural approaches
- **No implementation code yet** — spectech.md is the blueprint, not the code
