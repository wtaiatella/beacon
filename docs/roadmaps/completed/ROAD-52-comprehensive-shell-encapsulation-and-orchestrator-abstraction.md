### ROAD-52: Comprehensive Shell Encapsulation & Orchestrator Abstraction

**Priority:** High  
**Category:** Architecture / Orchestration  
**Status:** Completed  
**Complexity:** Large  
**Dependencies:** ROAD-51

#### Description
The Orchestrator (`run-pipeline/SKILL.md`) currently suffers from severe "Shell Bloat," executing raw, ad-hoc bash commands, chaining scripts with `cd ... && ...`, writing inline Python (`python3 -c 'import json...'`), and endlessly probing the Git tree (`git ls-files`, `git check-ignore`, `git diff --stat`). This is an anti-pattern that increases token usage, reduces auditability, and introduces the risk of hallucinated syntax errors. This roadmap will encapsulate all required Orchestrator operations into a strict library of bounded, safe, and audited wrapper scripts.

#### Goal
- **Zero Raw Shell Logic:** The Orchestrator must be explicitly forbidden from writing inline scripts, chaining commands with `&&` or `;`, or using raw `git` commands.
- **Git Operations Abstraction:** Replace the chaotic Git probing with a standardized `git-inspect.sh` tool, and wrap state mutations in a safe `pipeline-finish.sh` hook.
- **Init & Telemetry Consolidation:** Consolidate the verbose startup and logging chains into single-call wrapper scripts to streamline the transcript.
- **Skill Markdown Reduction:** Strip all raw bash instructions from `run-pipeline/SKILL.md` and replace them with a clean "API" of permitted script executions.

#### Detailed Workflow to Audit & Enforce

**1. Pipeline Initialization (`scripts/hooks/pipeline-init.sh`)**
- Create a single script to handle the entire Pre-Flight and Init sequence.
- **Replaces:** The messy `git rev-parse` branch check, the inline Python `.cursor/mcp.json` check, and the chained `session-memory.sh begin-run && write-trace-anchors && apply-models.sh --snapshot 2>/dev/null; session-memory.sh read`.
- **Output:** A structured, bounded report mapping the branch state, MCP availability, and session anchors for the Orchestrator to ingest in one go.

**2. Git Inspection / Telemetry (`scripts/tools/git-inspect.sh`)**
- Create a read-only Git utility for the Orchestrator.
- **Replaces:** `git status -sb`, `git diff --stat`, `git ls-files`, `git check-ignore`, `git show --name-only`.
- **Behavior:** When the Orchestrator needs to know what files changed or if a spec is git-ignored, it runs `git-inspect.sh <optional-path>`. The script returns a formatted, token-efficient summary (Tracked, Untracked, Ignored, Diff Stats) eliminating the need for the LLM to guess Git CLI flags.

**3. Pipeline Finish & Safe Mutation (`scripts/hooks/pipeline-finish.sh`)**
- Create a strict wrapper for end-of-run state changes.
- **Replaces:** Ad-hoc `git add`, `git commit -m`, `git push`, and manual `python3 audit-session-trace.py` chaining.
- **Behavior:** Takes explicit arguments: `--commit-message "..."` and `--push <true/false>`. It safely executes the git operations, catches hook errors gracefully, and **automatically** runs the context audit script, ensuring the observability layer is never accidentally skipped.

**4. Telemetry Abstraction (`scripts/tools/log-gate.sh`)**
- Create a dedicated telemetry logger.
- **Replaces:** `cd <dir> && scripts/tools/session-memory.sh write "GATE: ..." && scripts/tools/session-memory.sh write "impl | DONE..."`
- **Behavior:** Allows the orchestrator to log phase transitions and gates with a cleaner syntax without path-traversal acrobatics.

**5. Skill.md Enforcement (The Law)**
- Update `run-pipeline/SKILL.md` with a strict new non-negotiable:
  > **No Raw Shell Scripting:** You are forbidden from chaining commands (no `&&`, `||`, `;`), writing inline Python/Bash, or executing raw `git` commands. You may ONLY execute the pre-defined wrapper scripts in `scripts/hooks/` and `scripts/tools/`. Pass arguments clearly.

#### Deliverables
- [x] **The Scripts:** Implement `pipeline-init.sh`, `git-inspect.sh`, `pipeline-finish.sh`, and `log-gate.sh`.
- [x] **Skill Refactor:** Strip all raw shell instructions and inline code from `run-pipeline/SKILL.md` and document the new wrapper scripts.
- [x] **Verification:** Run a full pipeline and verify that the `context-audit.log` shows the Orchestrator calling only single `.sh` files, with zero chained or raw commands.