### ROAD-54: "Shift-Left" Security — Scrum Gate Aggregation

**Priority:** High  
**Category:** Architecture / Security  
**Status:** Completed  
**Complexity:** Medium  
**Dependencies:** ROAD-50, ROAD-51

#### Description
Currently, security validation is deferred to the End-of-Pipeline QA wave (§ 7.0). To implement a "Shift Left" security posture without introducing new LLM personas or "Two Bosses" conflicts, the automated `security-scanner` will be integrated into the Phase Implementation Review (§ 6). Rather than burdening domain reviewers with security analysis, the scanner's artifact will feed directly into the `scrum` agent alongside the reviewer scores, allowing `scrum` to act as the ultimate phase gatekeeper for both quality and security.

#### Goal
- **Parallel Execution:** Update the Orchestrator to run the automated `security-scanner` script in parallel with the `*-reviewer` tasks during Phase 6.
- **Scrum Aggregation:** Inject the resulting `artifacts/scanners/phase-X-security.md` artifact into the `Task(scrum)` prompt.
- **Unified Rework Loop:** Empower the `scrum` agent to issue a `REWORK` verdict if the security scanner flags High/Critical vulnerabilities, synthesizing the security fix and the code-quality feedback into a single `IMPL_SEGMENT_FEEDBACK` block for the `dev` agent.

#### Detailed Workflow to Audit & Enforce

**1. The Phase 6 Orchestration Update (`run-pipeline/SKILL.md`)**
- Modify **§ 6 Implementation review**.
- When the Orchestrator spins up the parallel `Task(*-reviewer)` agents, it simultaneously executes the `security-scanner` script (scoped to the current phase's diff).
- The Orchestrator persists this to `artifacts/scanners/phase-<N>-security.md`.

**2. The Least Privilege Injection Update**
- Update the injection matrix for **§ 6 `Task(scrum)`**.
- `scrum` now receives:
  1. The Reviewer scores and findings.
  2. `artifacts/scanners/phase-<N>-security.md`.
- *Note: `scrum` does not need the raw diffs; it relies on the reviewer and scanner summaries.*

**3. Agent Prompt Augmentation (`.cursor/agents/scrum.md`)**
- Update the `scrum.md` persona.
- Add explicit instructions: *"You are the final gatekeeper for this phase. You will receive domain reviewer scores and a security scanner report. If the security report flags High or Critical vulnerabilities, you MUST issue a REWORK verdict, regardless of the reviewer scores. Combine the security fixes and reviewer feedback into a single, actionable feedback block for the implementer."*

#### Deliverables
- [x] **Skill Update:** Modify `run-pipeline/SKILL.md` § 6 to include the parallel security scan and update the `scrum` injection payload.
- [x] **Agent Update:** Augment `scrum.md` to enforce High/Critical security findings as hard blockers for the `PROCEED` gate.
- [x] **Artifact Scaffold:** Ensure `session-memory.sh` or the Orchestrator handles phase-specific naming for scanner outputs to avoid overwriting them across phases.
- [x] **Verification (documented for this delivery):** Tabletop + `verify-qa-git-boundaries.sh` + session notes under `docs/sessions/<id>/artifacts/road-54-phase3-verification.md`. Optional follow-up: full `/run` E2E with deliberate insecure pattern (see spec Phase 3).
