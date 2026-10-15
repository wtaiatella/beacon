# Manual verification — phased implementation (implementation segment)

Use this checklist to validate **phased implementation**, **domain isolation**, **mutation guardrails**, and **`--resume`** behavior for **`/run`** orchestration. Authoritative procedure remains **`agentic/skills/run-pipeline/SKILL.md`** (**§ 5** — *Implementation payload construction*, **§ 6**, **Interaction with `--resume`**).

**Scope:** Human or live-session verification only; Cursor does not expose a guaranteed raw **`Task`** API. Adapt capture methods to your environment (Cursor UI, exported chat, orchestrator notes, or **`<ticket>/_run/timeline.md`** excerpts).

---

## Evidence to capture (all tests)

For each test run, keep a short **evidence pack** so results are auditable later:

| Artifact | What to record |
|----------|----------------|
| **Run timeline** | Path to **`<ticket>/_run/timeline.md`**. |
| **GATE lines** | Relevant **`GATE:`** lines from **`timeline.md`** (copy/paste or screenshot). Multi-phase runs should show **`GATE: impl \| DONE \| phase: k \| spec: …`** per skill. |
| **Task prompt excerpt** | **Redacted** copy of the orchestrator-built **`Task(dev)`** / **`Task(sre)`** / **`Task(data)`** body (remove secrets, internal URLs, or long unrelated context). Enough to show **included** phase heading and **domain-tagged** bullets only. |
| **Spec path & timing** | Active spec path under **`docs/specs/`**; optional **`stat`** output or IDE “last modified” **before** and **after** key gates. |
| **Orchestration narrative** | Short note of observed order (e.g. “phase 1 §6 scrum PROCEED → patch applied → phase 2 §5 started”). |

If the UI does not show full **`Task`** payloads, document that limitation and rely on **session notes**, **orchestrator self-logging** (if your team adds one line per delegation), or **`IMPL_SEGMENT_FEEDBACK:`**-style lines in **`timeline.md`**.

---

## Test 1 — Domain isolation

**Goal:** For a **multi-domain** spec in **phase 1 only**, the orchestrator’s **`Task(dev)`** payload must include **only** phase-1 **`[dev]`** task bullets — **not** **`[sre]`** or **`[data]`** task text for that phase (see skill **Implementation payload construction**).

### Preconditions

- Fixture spec (or temporary branch) with **`### Phase 1:`** containing **at least one** unchecked **`[dev]`**, **`[sre]`**, and **`[data]`** line (or two domains if **`data`** is absent — adjust assertions accordingly).
- Orchestration uses **`[DELEGATION MODE: orchestrated]`** (or equivalent) so implementation personas return **Proposed completions** only.

### Steps

1. Start **`/run`** targeting that spec through **§ 5** for **phase 1** until the orchestrator is about to invoke **`Task(dev)`** for **Phase 1**.
2. **Before** the delegate runs: capture the **full** orchestrator-prepared **`Task(dev)`** prompt (or the closest available: Cursor subagent panel, copy-paste, or logged summary).
3. **Inspect** the prompt body:
   - **Must include:** **`### Phase 1:`** (or equivalent) and **only** **`[dev]`**-tagged unchecked task lines for that phase (plus allowed shared blocks per skill: delegation header, **`WORKTREE_PATHS`**, condensed **Pre-plan** if present).
   - **Must not include:** **`[sre]`** or **`[data]`** **task bullet lines** from phase 1 (search for `[sre]` / `[data]` in the task-list portion). Overview/Scope one-line summaries are allowed per skill; **other domains’ task bullets** are not.
4. Optionally repeat for **`Task(sre)`** / **`Task(data)`** in the same phase: their payloads must **not** contain the **other** domains’ task bullets.

### Pass criteria

- No **`[sre]`** or **`[data]`** task lines appear in the **`Task(dev)`** payload for phase 1.
- Evidence pack includes a **redacted** prompt excerpt or explicit note that UI could not expose it + alternative proof (e.g. orchestrator checklist attestation + **`timeline.md`** line describing slice).

### Fail / document

- If any other domain’s bullets appear in **`Task(dev)`**, record as **fail** and file follow-up against **run-pipeline** payload rules.

---

## Test 2 — Phase gating

**Goal:** For a **two-phase** spec, **phase 2** **`Task(dev|sre|data)`** must **not** start until **phase 1** **§ 6** completes (**`*-reviewer`** + **`Task(scrum)`** **PROCEED**) **and** the orchestrator has applied **Proposed completions** / spec updates for phase 1.

### Preconditions

- Spec with **`### Phase 1:`** and **`### Phase 2:`**, each with at least one implementation task (any domain).
- Ability to observe ordering (session transcript, **`GATE:`** lines, or step-by-step log).

### Steps

1. Run **`/run`** until **phase 1 § 5** implementation **`Task`** delegations complete.
2. Confirm **§ 6** runs for **phase 1** (reviewers + **`Task(scrum)`**) **before** any **`Task(dev|sre|data)`** whose title or body references **Phase 2**.
3. Confirm the orchestrator **applies** phase-1 **Proposed completions** (checkboxes / **`last-updated`**) **only after** **`Task(scrum)`** **PROCEED** for phase 1 — not before.
4. **After** that patch, confirm the **next** implementation delegation is for **phase 2** (separate **`Task`** per phase per domain, per skill).

### Pass criteria

- Observable order: **phase 1 §5 → phase 1 §6 (PROCEED + patch) → phase 2 §5**.
- **`GATE:`** in **`timeline.md`** after phase 1 **§ 6** includes something like **`GATE: impl | DONE | phase: 1 | spec: …`** (see skill **§ 6** checkpoint).

### Fail / document

- Any **Phase 2** **`Task(dev|sre|data)`** starting **before** phase 1 **§ 6** **PROCEED** + patch is **orchestration failure** per **`agentic/adapters/cursor/rules/00-workspace-router.mdc`** invalid-pipeline rules.

---

## Test 3 — Mutation guardrails (spec mtime)

**Goal:** Under orchestration, **`Task(dev)`** (and other implementation personas) **do not** directly edit **`docs/specs/*`**; the spec file **mtime** should **not** change at **`Task(dev)`** completion — only **after** the orchestrator applies patches following **`Task(scrum)`** **PROCEED**.

### Preconditions

- Active spec path: **`SPEC=docs/specs/<your-spec>.md`**.
- Git working tree may show edits only from the **orchestrator** after gates (not from subagent direct writes).

### Steps

1. Record baseline:  
   `stat -f "%m %N" "$SPEC"` (macOS) or `stat -c "%y %n" "$SPEC"` (Linux), or note IDE “last modified”.
2. Run **`/run`** until **`Task(dev)`** returns (phase 1 or single phase).
3. **Immediately** re-check **`stat`** / IDE timestamp on **`$SPEC`**. **Expect no change** if the dev persona followed **Proposed completions** only.
4. Continue through **§ 6** until **`Task(scrum)`** **PROCEED**; orchestrator applies **Proposed completions** to the spec.
5. Re-check **`stat`**. **Expect** timestamp to move **only after** step 4 (same second as patch is OK).

### Pass criteria

- No spec file modification **between** step 1 and end of **`Task(dev)`** (step 3).
- Modification **after** orchestrator patch post-**PROCEED** (step 5).

### Caveats

- If the **orchestrator** or hooks **touch** the spec for unrelated reasons, note that in the evidence pack.
- **`format-on-edit`** or auto-save could change mtime without semantic edits — if observed, document tool behavior separately.

---

## Test 4 — Session resume (`/run --resume`)

**Goal:** If the run **stops during phase 2 § 5** (before phase 2 **§ 6**), **`/run --resume`** continues **phase 2 § 5** using **`GATE:`** history — **without** redoing **phase 1 § 5–§ 6**, unless you are in a documented **recovery** scenario (corrupt session, manual edit of **`timeline.md`**, etc.).

### Preconditions

- Two-phase spec; **`<ticket>/_run/timeline.md`** writable.
- Orchestrator follows skill: after phase 1 **§ 6**, persist  
  **`GATE: impl | DONE | phase: 1 | spec: <path>`**.

### Steps

1. Run **`/run`** until phase 1 **§ 6** completes and the line above exists in **`timeline.md`** (verify with **`grep GATE`** or read file).
2. Proceed into **phase 2 § 5**; **stop** the run **before** phase 2 **§ 6** (abort chat, cancel, or simulated failure — **not** after **`GATE: impl | DONE | phase: 2`**).
3. Confirm the **last** **`GATE: impl | DONE`** line is still **`phase: 1`** (skill: if run stops **during** phase 2 § 5, last impl-done should remain phase 1).
4. Run **`/run --resume`** (same branch/session as documented in skill).
5. Observe continuation: **phase 2 § 5** work resumes; **phase 1 § 5–§ 6** are **not** repeated.
6. Inspect **`timeline.md`** for **`GATE:`** lines: should still show phase 1 completion; resume narrative should align with skill **Interaction with `--resume`**.

### Pass criteria

- **`--resume`** does **not** re-invoke **phase 1** **`Task(dev|sre|data)`** or **phase 1 § 6** unless documented as recovery.
- **`GATE:`** history remains consistent (phase 1 done; phase 2 not yet **`GATE: impl | DONE | phase: 2`**).

### Recovery exception (document if used)

- If **`timeline.md`** is missing **`GATE: impl | DONE | phase: 1`**, a **full re-run** or manual repair may be required — **not** a failure of this checklist’s scenario if called out explicitly in the evidence pack.

---

## Quick reference — authoritative strings

| Topic | Location |
|-------|----------|
| One phase / one domain per **`Task`** | **`agentic/skills/run-pipeline/SKILL.md`** — **Implementation payload construction**, **Anti-patterns** |
| **`GATE: impl \| DONE \| phase: k`** | Same file — **§ 6**, **Interaction with `--resume`** |
| Invalid completion (skipped § 6, etc.) | **`agentic/adapters/cursor/rules/00-workspace-router.mdc`** — **Invalid pipeline output** |
| Session layout | **`docs/run-pipeline-reference.md`** — **Session storage** |

---

## Related

- **`docs/reference/nested-task-audit.md`** — flat **`Task`** policy for implementation personas.
- **`docs/run-pipeline-reference.md`** — **Manual verification (plan segment)** for plan-segment tests (complementary).
