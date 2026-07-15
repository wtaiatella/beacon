### ROAD-09: stop Hook Auto-Verification

**Priority:** Medium
**Category:** Security
**Status:** Completed
**Complexity:** Small

#### Description

End-of-session verification hook that checks for uncommitted secrets, security markers, hook health, and spec inconsistencies.

#### Deliverables

- [x] `session-verify.sh` hook: checks for new `.env` files, `TODO: REMOVE` / `FIXME: SECURITY` markers, non-executable hook scripts, and specs with `status: review` but unchecked tasks. Returns warnings array.

---
