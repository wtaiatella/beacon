### ROAD-49: Transcript Audit Traversal & Timezone Fix

**Priority:** High  
**Category:** Tooling / Observability  
**Status:** Completed
**Complexity:** Small  
**Dependencies:** ROAD-40

#### Description
The ROAD-40 audit script (`audit-session-trace.py`) is failing to locate Cursor's internal `.jsonl` transcript files. Diagnostic tests confirmed the files exist but are nested inside UUID-named subdirectories (e.g., `agent-transcripts/<uuid>/<uuid>.jsonl`). Because the script currently performs a flat directory scan, it returns zero matches. Furthermore, there is a risk of false negatives due to timezone discrepancies between the `SESSION_START` UTC anchor and the local file system's modification time (`mtime`).

#### Goal
- **Recursive Search:** Patch the audit script to recursively traverse the `agent-transcripts` directory to locate deeply nested files.
- **Strict Timezone Math:** Ensure both the session anchor and the file `mtime` are explicitly cast to UTC before comparison to guarantee accurate time-window bounding.

#### Detailed Workflow to Audit & Enforce

**1. The Traversal Patch**
- Update `scripts/tools/audit-session-trace.py`.
- Replace `os.listdir()` or flat `glob()` implementations with Python's `pathlib.Path.rglob('*.jsonl')` to force the script to search inside all UUID subfolders.

**2. The Timezone Patch**
- Ensure the `SESSION_START` string (e.g., `2026-04-11T00:56:26.202Z`) is correctly parsed into a UTC datetime object.
- Extract the file `mtime` using `st_mtime` and explicitly convert it to a UTC datetime object using `datetime.datetime.fromtimestamp(..., tz=datetime.timezone.utc)`.
- Compare the two normalized objects.

#### Deliverables
- [ ] **Script Update:** Apply the `rglob` and UTC timezone fixes to `audit-session-trace.py`.
- [ ] **Verification:** Execute a test pipeline run (or run the script manually against the recent `2026-04-11T00:56:26.202Z` session anchor).
- [ ] **Log Validation:** Verify that `docs/sessions/<id>/context-audit.log` successfully populates with the found transcripts, including their token counts and context payloads.