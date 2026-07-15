### ROAD-48: Dynamic Multi-Root Project Attachment & Workspace Generation

**Priority:** Medium  
**Category:** Tooling / Workflow  
**Status:** Completed  
**Complexity:** Medium  
**Dependencies:** ROAD-35, ROAD-42, ROAD-46

#### Description
Transform the Orchestrator into a "Portable AI Command Center." Implement a dynamic attachment mechanism that allows the user to select a target project from a local directory and automatically generates a Cursor Multi-Root Workspace (`.code-workspace`). This setup ensures perfect GitLens support, isolated transcripts, and clear "Handoff" boundaries, allowing the Orchestrator to work on external repositories without polluting them with framework files.

#### Goal
- **Persistent Configuration:** Allow the user to set their `PROJECTS_ROOT` path once, saving it to a local gitignored config file so they aren't repeatedly prompted.
- **Interactive Selection:** Build a zero-dependency CLI picker (using a native Bash `select` loop) to choose a target repository from the configured `PROJECTS_ROOT`.
- **Workspace Generation:** Automatically generate and launch a `.code-workspace` file that joins the Orchestrator (Read-Only context) and the Target Project (Writeable execution).
- **Session-Linked Detachment:** Implement a cleanup/handoff protocol that archives session data and deletes the temporary workspace file once the pipeline is complete.

#### Detailed Workflow to Audit & Enforce

**1. The Attachment Script (`scripts/tools/attach-project.sh`)**
- Check for a `.env.local` file (gitignored) containing `PROJECTS_ROOT`. If missing, prompt the user for the path and save it to the file for all future runs.
- Use a native Bash `select` menu to list subdirectories within `PROJECTS_ROOT`, allowing the user to pick a project by entering a number.
- Generate a `docs/sessions/<id>/session.code-workspace` file with the following JSON structure:

    {
      "folders": [
        { "name": "Orchestrator", "path": "../../.." },
        { "name": "Target", "path": "/absolute/path/to/selected-repo" }
      ],
      "settings": {
        "git.scanRepositories": [ "/absolute/path/to/selected-repo" ]
      }
    }

- Launch Cursor using the generated workspace file: `cursor docs/sessions/<id>/session.code-workspace`.

**2. Pipeline Context Awareness**
- Update `run-pipeline/SKILL.md`. The Main Agent must detect if it is in a Multi-Root environment.
- **Enforcement:** All Git commands and implementation tasks (dev, sre, data) must explicitly use the Target folder as the `working_directory`.
- The `PROJECT_HASH` for ROAD-40 auditing must be resolved from the Target folder path, not the Orchestrator folder.

**3. The Handoff/Detach (§ 9 Finish)**
- After Git actions are resolved, the Orchestrator asks: "Pipeline complete. Detach and archive workspace?"
- If "Yes":
  - The `.code-workspace` file is deleted.
  - The session metadata is finalized.
  - The user is prompted to return to the standard Orchestrator view.

#### Deliverables
- [x] Config Manager: Update workspace to support a `.env.local` file for persistent user preferences.
- [x] CLI Picker: Create `scripts/tools/attach-project.sh` utilizing a zero-dependency Bash `select` loop and config loading.
- [x] Template Engine: Build a simple shell/python helper to generate the valid JSON `.code-workspace` file.
- [x] Orchestrator Update: Update the Init and Finish logic in `run-pipeline/SKILL.md` to handle multi-root paths.
- [x] Verification: Successfully attach the orchestrator to an external repo, execute a `/run` that modifies a file in the target repo, and verify GitLens annotations are accurate.