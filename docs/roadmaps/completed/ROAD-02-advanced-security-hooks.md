### ROAD-02: Advanced Security Hooks

**Priority:** High
**Category:** Security
**Status:** Completed
**Complexity:** Medium

#### Description

Pre-execution gates for shell commands and file reads that reduce accidental destructive operations and limit exposure of secrets in agent context.

#### Deliverables

- [x] `beforeShellExecution` hook (`before-shell.sh`): blocks `rm -rf /`, force-push to protected branches, destructive SQL, `chmod 777`, fork bombs. Logs blocked commands to `docs/audit.log`.
- [x] `beforeReadFile` hook (`before-read.sh`): blocks reads of `.env`, `*.pem`, `*.key`, `~/.ssh/*`, `~/.aws/credentials`, `~/.kube/config`, and paths containing `/secrets/` or `/credentials/`.

---
