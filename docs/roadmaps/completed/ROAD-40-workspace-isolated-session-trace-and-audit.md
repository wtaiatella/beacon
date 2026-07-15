### ROAD-40: Workspace-Isolated Session Trace & Audit

**Priority:** High
**Category:** Tooling / Optimization
**Status:** Completed
**Complexity:** Medium
**Dependencies:** ROAD-35, ROAD-42

#### Description

Implement an end-to-end "Session Trace" that remains accurate even in high-concurrency, multi-repository environments. By anchoring the audit to both a high-precision `SESSION_START` timestamp and a unique **Workspace Project Hash**, we ensure that auditing telemetry is strictly isolated to the active repository, preventing cross-contamination from parallel pipelines.

#### Goal

- **Project-Aware Initialization:** Record the unique workspace project hash alongside the `SESSION_START` anchor during pre-flight.
- **Isolated Transcript Correlation:** Refine the Python audit utility to strictly scan the transcript subdirectories associated with the current project's Cursor hash.
- **Race-Condition Prevention:** Ensure the audit sweep correctly identifies subagent calls belonging only to the active Main Agent session.

#### Detailed Workflow to Enforce

**1. Pre-Flight Anchor (§ 2 Init)**
- The Main Agent executes a script to resolve its local Cursor Project Hash (often found by hashing the absolute path of the workspace root or checking the IDE's environment).
- Write `SESSION_START` and `PROJECT_HASH` to `docs/sessions/<id>/current.md`.

**2. The Isolated Sweep Utility (`audit-session-trace.py`)**
- The script reads both the `SESSION_START` and the `PROJECT_HASH`.
- **Targeted Scan:** It navigates directly to `~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`.
- **Time Filter:** It filters for `.jsonl` files modified after `SESSION_START`.
- **Metadata Extraction:** It extracts token counts, system prompt slices, and file-inclusion lists for the final audit.

**3. Final Integration (§ 9 Finish)**
- Before pipeline completion, the Main Agent runs the sweep for its specific project context.
- The results are logged to `docs/sessions/<id>/context-audit.log`.

#### Deliverables & Test Cases

- [ ] **Hash Resolution Tool:** Create a utility to reliably identify the current workspace's Cursor project hash from the shell.
- [ ] **Develop the Isolated Trace Utility:** Build the Python script to correlate transcripts using both the timestamp and the project hash.
- [ ] **Parallel Stress Test:** Launch two separate `/run` pipelines in two different repositories simultaneously. Verify that `context-audit.log` in Repo A contains zero traces from the execution in Repo B.
- [ ] **Audit Payload Accuracy:** Verify the "Least Privilege" context rules by checking that the audited token counts reflect the sliced specs, not the full codebase.

---
