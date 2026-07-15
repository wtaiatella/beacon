### ROAD-41: README.md Overhaul & Mermaid Architecture Diagrams

**Priority:** Medium
**Category:** Documentation / Onboarding
**Status:** Completed (2026-04-11)
**Complexity:** Medium
**Dependencies:** ROAD-36 through ROAD-55

#### Description

Overhaul the repository `README.md` to serve as an objective, highly readable, information-dense map for human engineers. The current README is becoming bloated with procedural text that belongs in `SKILL.md` or `.cursor/rules/`. This update will aggressively trim redundant text and replace it with rich, accurate Mermaid diagrams that visually enforce the "Portable AI Command Center" architecture. It must specifically highlight our newest structural pillars: Flat Orchestration, Multi-Root Workspaces, Least Privilege Artifact routing, "Shift-Left" Scrum Security, and the Zero-Trust Script API.

#### Detailed Workflow to Audit & Enforce

The updated `README.md` must be restructured to include the following visual and textual components:

**1. The "Zero-Trust Hub-and-Spoke" Architecture Diagram**
- **Objective:** Visually prove that nested subagents are banned, shell access is restricted, and context is tightly controlled.
- **Implementation:** Create a Mermaid `flowchart TD` placing the **Main Agent (Orchestrator)** at the exact center. 
  - Show specialized MCP and Scanner agents feeding artifacts into `docs/sessions/<id>/artifacts/`.
  - Show implementation agents (`dev`, `qa`, `do`) receiving *only* authorized artifacts and executing mutations *only* via the `scripts/tools/` API (e.g., `archive-roadmap.sh`, `transcript-query.py`).
  - Add a bolded callout for the "Law of Flat Orchestration & Zero-Trust Shell."

**2. The End-to-End Command Center State Machine**
- **Objective:** Illustrate the exact pipeline execution order, including dynamic workspaces, pipeline waves, and hook encapsulations (ROAD-52, ROAD-55).
- **Implementation:** Create a Mermaid `stateDiagram-v2`. 
  - Transitions: `Workspace Attach` ➔ `pipeline-preflight.sh` ➔ `Wave 1 (Glean/ARC)` ➔ `Wave 2 (Gated)` ➔ `Plan Loop` ➔ `Phase Execution` ➔ `Phase Review & Security Scan (Shift-Left)` ➔ `QA` ➔ `Summary` ➔ `pipeline-finish.sh`.
  - Clearly mark the states where the pipeline pauses for Human Input or triggers automated wrapper scripts.

**3. Phase Execution, Shift-Left Security, & Scrum Gates**
- **Objective:** Clarify parallel implementation, the dual Code/Security review loop, and the "Definition of Done" (ROAD-54).
- **Implementation:** Create a Mermaid `sequenceDiagram`.
  - Show the Orchestrator broadcasting tasks to `dev`, `sre`, and `data` in parallel.
  - Show Phase 6 running `*-reviewer` and the automated `security-scanner` script in parallel.
  - Show both reviewer scores and security artifacts feeding into `Task(scrum)`.
  - Show `scrum` bouncing the task back to `dev` (REWORK) or authorizing `Task(do)` to patch the Spec (PROCEED).

**4. The Session Anatomy Directory Map (Strict Mode)**
- **Objective:** Document the observability platform and strict cleanliness policy (ROAD-51, ROAD-53).
- **Implementation:** Provide a clean text-tree of `docs/sessions/<id>/` showcasing `current.md`, `context-audit.log`, and the `artifacts/` subdirectories (`diffs/`, `scanners/`, `mcp-briefs/`). Add explicit documentation stating that root-level session files and backward-compatibility symlinks are strictly forbidden.

**5. Aggressive Text Trimming (The "Human Readable" Pass)**
- Move highly specific agent instruction prompts out of the README and rely on links to `docs/reference/*` and `.cursor/rules/`.
- Ensure the removal of all historical `ROAD-XX` references in the generic documentation blocks to prevent staleness.

#### Deliverables & Test Cases

- [x] **Draft Visuals:** Write and render the Mermaid diagrams to ensure they compile correctly in GitHub/GitLab markdown viewers.
- [x] **Restructure Document:** Rewrite the `README.md` using the new diagrams as the anchors for each section.
- [x] **Audit Readability:** Ensure the total word count is significantly reduced while actual architectural clarity is increased. 
- [x] **Verify Links:** Ensure all links point accurately to the updated session folders, the script API library, and the `.mdc` rules.