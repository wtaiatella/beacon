### ROAD-46: Pipeline Finish & Audit Reliability Review

**Priority:** High  
**Category:** Quality / Orchestration  
**Status:** Completed
**Complexity:** Large  
**Dependencies:** ROAD-40, ROAD-42

#### Description

Audit and stabilize the end-of-pipeline behavior (§ 7-9). Recent runs show three regressions: (1) The Main Agent occasionally deviates from using the `AskQuestion` tool for Finish prompts, (2) `current.md` log entries are appearing out of chronological order (Context/Pre-plan blocks), and (3) the ROAD-40 Audit script is failing to find `.jsonl` transcripts because they are either not yet flushed to disk or the Workspace Hash logic is inconsistent between "Folder" and "Workspace" modes.

#### Goal

- **Harden `AskQuestion` Usage:** Enforce the use of the `AskQuestion` tool via stricter "Non-negotiable" rules in the SKILL to prevent chat-only deviations.
- **Fix Log Ordering:** Refactor `session-memory.sh` or the Orchestrator's writing logic to ensure `current.md` is strictly append-only at the bottom, maintaining a perfect timeline.
- **Solve Audit "Zero-Found" Bug:** Investigate the transcript flush timing. If Cursor delays writing JSONL files, implement a "Delayed Audit" or "Self-Audit" pattern that can look back at the *previous* run's transcripts.
- **Granular Implementation Logging:** Separate `TASK_START` and `GATE_RESULT` logs so implementation duration and review duration are tracked independently.

#### Detailed Workflow to Audit & Enforce

**1. Finish Prompt Enforcement (§ 9)**
- Add a strict instruction: "If `AskQuestion` is available, you ARE FORBIDDEN from writing Finish choices A-E directly to chat. You must call the tool."
- Ensure the Orchestrator knows how to "Await" the tool response before proceeding to Git actions.

**2. Chronological Persistence (`current.md`)**
- Audit the `session-memory.sh` script. Ensure it doesn't use `sed` or `awk` to insert blocks in a way that shifts the "Pre-plan" block to the bottom. Every write should be a simple `>>` append.
- Standardize the "PIPELINE: COMPLETE" block to always be the final bytes of the file.

**3. Transcript Sync & Hash Resolution**
- **The Hash Bug:** Verify if `PROJECT_HASH` differs when opening the project as a `.code-workspace` vs. a standard folder.
- **The Flush Bug:** Test if adding a 2-5 second `sleep` before the audit script runs allows Cursor to flush the `.jsonl` to disk. 
- If the current run's transcript is consistently invisible to itself, refactor ROAD-40 to be a **"Pre-Flight Audit"** that analyzes the *previous* session's context at the start of a *new* run.

**4. Implementation Telemetry**
- Modify § 5/6 logic: 
  - Log `[Timestamp] | impl | START | phase N | domain X` 
  - Log `[Timestamp] | impl | DONE | phase N | domain X`
  - Log `[Timestamp] | impl-review | GATE | score% | decision`
- This prevents implementation and review from being "smushed" into a single confusing timestamp.

#### Deliverables

- [ ] **Fix `AskQuestion` deviation:** Update `run-pipeline/SKILL.md` § 9 with a "Tool-First" mandate.
- [ ] **Fix `current.md` ordering:** Ensure `begin-run` and `finish` writes are strictly chronological.
- [ ] **Fix Audit Zero-Result:** Debug the `PROJECT_HASH` and `mtime` window. If the JSONL is not found, the script should output a diagnostic list of *all* found UUIDs and their timestamps to identify the mismatch.
- [ ] **Telemetry Update:** Split implementation and review logs in the session memory.

#### Notes

- The audit failure is the highest priority. If we can't see the context, we can't prove the "Least Privilege" rule is being followed.