### ROAD-55: Absolute Shell Deprecation & The `Task(do)` Execution API

**Priority:** High  
**Category:** Architecture / Orchestration  
**Status:** Completed  
**Complexity:** Medium  
**Dependencies:** ROAD-52

#### Description
Despite the Orchestrator shell encapsulation in ROAD-52, execution agents—specifically `Task(do)`—are still falling back to complex, hallucination-prone shell acrobatics. Recent transcripts show the `do` agent writing inline Python to parse `.jsonl` transcripts, using raw `rg`/`wc` pipelines, and manually executing `git mv` and `git add` to archive completed roadmaps. This roadmap item introduces a strict "Zero Trust Shell" policy for subagents, replacing these rogue operations with dedicated, safe script APIs.

#### Goal
- **Transcript Query API:** Provide a safe, read-only script for agents to extract specific data from session transcripts without writing custom JSON parsers.
- **Roadmap Archival API:** Encapsulate the complex Git staging and moving required to archive a roadmap into a single script.
- **Hard Guardrails:** Explicitly forbid inline Python, `awk`/`sed` pipelines, and mutating `git` commands inside the `do.md` agent prompt, and enforce this via the workspace linter.

#### Detailed Workflow to Audit & Enforce

**1. The Transcript Query Wrapper (`scripts/tools/query-transcript.py`)**
- Create a read-only utility designed specifically for LLM consumption.
- **Behavior:** Takes arguments like `--session-id <id>`, `--role <assistant/user>`, and `--grep "Security Scan"`.
- **Output:** Returns plain text blocks of the requested transcript content, completely shielding the LLM from the underlying JSONL AST and file traversal.

**2. The Roadmap Lifecycle Wrapper (`scripts/tools/archive-roadmap.sh`)**
- Create a dedicated script for the End-of-Pipeline roadmap sync.
- **Behavior:** Takes the roadmap ID (e.g., `ROAD-54`). It automatically handles the `git mv docs/roadmaps/ROAD-XX.md docs/roadmaps/completed/ROAD-XX.md` and the `git add`, completely removing raw Git mutations from the `do` agent's responsibilities.

**3. Agent Prompt Lockdown (`.cursor/agents/do.md` & `run-pipeline/SKILL.md`)**
- Update the `do` persona and the Main Agent's delegation headers.
- **New Non-Negotiable:** *"You are strictly forbidden from writing inline Python (`python3 -c`), inline Bash loops, or using raw `git mv` / `git add` commands. To query past transcripts, execute `scripts/tools/query-transcript.py`. To archive roadmaps, execute `scripts/tools/archive-roadmap.sh`. If a script does not exist for your complex task, escalate via QUESTION."*
- **Artifact Recreation Ban:** Instruct agents *never* to recreate missing automated artifacts (like scanner reports) from memory. If an artifact is missing, the agent must fail the task and instruct the Orchestrator to rerun the scanner script.

**4. Linter Enforcement (`scripts/tools/lint-check.sh`)**
- Add a regex sweep to the linter that scans `.cursor/agents/*.md` and `.cursor/skills/**/*.md`.
- Fail the lint check if forbidden patterns (`python3 -c`, `git mv`, `git commit`, `awk '{`) are found in the instructional text.

#### Deliverables
- [x] **Create Tools:** Implement `query-transcript.py` and `archive-roadmap.sh`.
- [x] **Prompt Lockdown:** Update `do.md` and the `run-pipeline` delegation headers to enforce the Zero Trust Shell policy.
- [x] **Linter Guardrail:** Update `lint-check.sh` to ban raw scripting syntax in agent definitions.
- [x] **Verification:** Delegate a `Task(do)` to archive a dummy roadmap and query a transcript, ensuring it uses only the new scripts with zero inline code.