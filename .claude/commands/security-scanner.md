---
description: "Performs deep security analysis on code changes. Orchestrated /run: dual persistence — §6 phase gate → artifacts/scanners/phase-<N>-security.md (default phase-1-security.md without ### Phase N: headings); §7.0 QA prep → security-scanner.md with spec-validator.md. Task(scrum) §6 and Task(qa) consume per LPP. Scans for injection vectors, auth bypass, data exposure, insecure dependencies, and OWASP Top 10 issues. Output is bounded Markdown (severity-first, concise findings). Use when you need a security pass during implementation review or QA prep."
argument-hint: "<target-dir>"
---

Run the read-only **security-scanner** subagent (Task tool, subagent_type `security-scanner`) on `$ARGUMENTS` and report its structured findings. This agent never mutates repo state.
