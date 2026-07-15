### ROAD-30: Audit Log Integrity & QA Test Isolation

**Priority:** Medium
**Category:** Security
**Status:** Planned
**Complexity:** Small
**Dependencies:** None

#### Description

The audit log (`docs/audit.log`) is meant to be an append-only record, but agents can write directly to the file bypassing the `audit-log.sh` hook. During the ROAD-27 pipeline run, the QA agent wrote test entries (`test-123`, `test-456`) to the production audit log, polluting real metrics data. Later, those entries were lost when the file was overwritten rather than appended.

Two problems: (1) QA tests should never mutate production data files, and (2) the audit log has no integrity protection beyond the hook's `appendFileSync`.

#### Deliverables

- [ ] Update `/qa` agent instructions: QA must use temp files (e.g., `/tmp/qa-test-audit.log`) for format/behavior validation, never write to `docs/audit.log` directly
- [ ] Add `scripts/tools/audit-write.sh` as the sole interface for writing audit entries (wraps the append logic, validates format, rejects test session IDs)
- [ ] Update `audit-log.sh` hook to use `audit-write.sh` instead of inline Node.js
- [ ] Add a `before-shell` hook pattern to warn when agents attempt to write directly to `docs/audit.log` via shell commands
- [ ] Clean up existing test entries from audit log (remove `test-123`, `test-456` rows)
- [ ] Add audit log format validation to `metrics.sh`: skip/warn on malformed or test entries

#### Notes

- The audit log is gitignored and local-only, so corruption is annoying but not catastrophic. The fix is primarily about data hygiene and preventing QA from polluting metrics.
- A lockfile or checksum approach is overkill for a local-only log. The main fix is behavioral: QA must not touch production files during testing.

---
